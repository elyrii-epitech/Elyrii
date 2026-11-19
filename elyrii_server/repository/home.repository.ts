import {and, count, eq, isNull} from "drizzle-orm";
import {db} from "../config/db.config";
import {homeActivitiesTable, homeCommandsTable} from "../config/db/home.table";
import {userTable} from "../config/db/user.table";
import {journalEntriesTable} from "../config/db/journal.table";
import {userChallengesTable} from "../config/db/quest.table";
import {emptyHome, HomeError, type HomeFacts, type HomeCommand} from "../modules/user/home.contracts";

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
type HomeRow = typeof homeActivitiesTable.$inferSelect;
const dayMs = 86400000;
const mondayOf = (day: string) => {
    const date = new Date(day + "T00:00:00Z");
    date.setUTCDate(date.getUTCDate() - (date.getUTCDay() + 6) % 7);
    return date.toISOString().slice(0, 10);
};
const document = (owner: string, row?: HomeRow) => ({schemaVersion: 1, owner, revision: row?.revision ?? 0, activities: row?.activities ?? emptyHome()});
function prune(facts: HomeFacts) {
    const today = Date.parse(new Date().toISOString().slice(0, 10));
    const keep = (day: string, allowance = 0) => Date.parse(day) >= today - (370 + allowance) * dayMs && Date.parse(day) <= today + dayMs;
    for (const day of Object.keys(facts.ritualDays)) if (!keep(day)) delete facts.ritualDays[day];
    for (const day of Object.keys(facts.socialWeeks)) if (!keep(day, 6)) delete facts.socialWeeks[day];
    const answers = Object.entries(facts.threadAnswers).sort((a, b) => Date.parse(b[1].answeredAt) - Date.parse(a[1].answeredAt));
    facts.threadAnswers = Object.fromEntries(answers.slice(0, 50));
    if (facts.journalQuestion && !keep(facts.journalQuestion.day)) facts.journalQuestion = null;
    facts.addedRituals = [...new Set(facts.addedRituals)];
    return facts;
}

export default class HomeRepository {
    async get(owner: string) {
        const [row] = await db.select().from(homeActivitiesTable).where(eq(homeActivitiesTable.userId, owner));
        if (row) row.activities = prune(row.activities);
        return document(owner, row);
    }
    private async locked<T>(owner: string, operation: (tx: Tx, current: HomeRow | undefined) => Promise<T>) {
        return db.transaction(async tx => {
            const [user] = await tx.select({id: userTable.id}).from(userTable).where(eq(userTable.id, owner)).for("update");
            if (!user) throw new HomeError("Compte introuvable.", 404);
            const [row] = await tx.select().from(homeActivitiesTable).where(eq(homeActivitiesTable.userId, owner));
            return operation(tx, row);
        });
    }
    private async ownedEntry(tx: Tx, owner: string, id: string) {
        const [entry] = await tx.select({id: journalEntriesTable.id}).from(journalEntriesTable)
            .where(and(eq(journalEntriesTable.id, id), eq(journalEntriesTable.userId, owner), isNull(journalEntriesTable.deletedAt)));
        return entry != null;
    }
    private async decorUnlocked(tx: Tx, owner: string, decor: string) {
        if (decor !== "clearing") return true;
        const [result] = await tx.select({count: count()}).from(userChallengesTable)
            .where(and(eq(userChallengesTable.userId, owner), eq(userChallengesTable.status, "COMPLETED")));
        return Number(result?.count ?? 0) >= 10;
    }
    private async save(tx: Tx, owner: string, facts: HomeFacts, current?: HomeRow) {
        const [saved] = await tx.insert(homeActivitiesTable).values({userId: owner, activities: prune(facts), revision: (current?.revision ?? 0) + 1})
            .onConflictDoUpdate({target: homeActivitiesTable.userId, set: {activities: facts, revision: (current?.revision ?? 0) + 1, updatedAt: new Date()}}).returning();
        return document(owner, saved!);
    }
    async importLocal(owner: string, input: {owner: string; activities: HomeFacts}) {
        if (input.owner !== owner) throw new HomeError("Les activités appartiennent à un autre compte.", 403);
        return this.locked(owner, async (tx, current) => {
            // The first device initializes the account. A legacy cache can
            // never re-check an item that another device has since unchecked.
            if (current) return document(owner, current);
            const facts = structuredClone(input.activities);
            for (const id of Object.keys(facts.threadAnswers)) if (!await this.ownedEntry(tx, owner, id)) delete facts.threadAnswers[id];
            if (!await this.decorUnlocked(tx, owner, facts.decor)) facts.decor = "arches";
            return this.save(tx, owner, facts);
        });
    }
    async command(owner: string, input: HomeCommand) {
        return this.locked(owner, async (tx, current) => {
            const hash = new Bun.CryptoHasher("sha256").update(JSON.stringify(input.command)).digest("hex");
            const [receipt] = await tx.select().from(homeCommandsTable).where(and(eq(homeCommandsTable.userId, owner), eq(homeCommandsTable.requestId, input.requestId)));
            if (receipt) {
                if (receipt.payloadHash !== hash) throw new HomeError("Identifiant de modification déjà utilisé.", 409);
                return document(owner, current);
            }
            const facts = structuredClone(current?.activities ?? emptyHome()), command = input.command;
            const now = new Date().toISOString();
            if ("day" in command && (Date.parse(command.day) < Date.now() - 371 * dayMs || Date.parse(command.day) > Date.now() + dayMs)) throw new HomeError("Date d’activité hors période.", 400);
            switch (command.kind) {
                case "ritual": {
                    const day = facts.ritualDays[command.day] ??= {};
                    if (command.done) day[command.ritual] ??= now;
                    else delete day[command.ritual];
                    break;
                }
                case "addRitual": facts.addedRituals.push(command.ritual); break;
                case "socialComplete": case "socialIdea": {
                    const week = facts.socialWeeks[mondayOf(command.day)] ??= {ideaIndex: 0, completedAt: {}};
                    if (command.kind === "socialComplete") week.completedAt[command.day] ??= now;
                    else week.ideaIndex = (week.ideaIndex + 1) % 1000001;
                    break;
                }
                case "thread":
                    if (!await this.ownedEntry(tx, owner, command.entryId)) throw new HomeError("Note introuvable.", 404);
                    facts.threadAnswers[command.entryId] ??= {reply: command.reply, answeredAt: now};
                    break;
                case "decor":
                    if (!await this.decorUnlocked(tx, owner, command.decor)) throw new HomeError("Ce décor n’est pas encore débloqué.", 403);
                    facts.decor = command.decor;
                    break;
                case "question": {
                    const previous = facts.journalQuestion;
                    const index = previous?.day === command.day ? previous.index : Math.floor(Date.parse(command.day) / dayMs);
                    facts.journalQuestion = {day: command.day, index: (index + 1) % command.count};
                    break;
                }
            }
            const saved = await this.save(tx, owner, facts, current);
            await tx.insert(homeCommandsTable).values({userId: owner, requestId: input.requestId, payloadHash: hash});
            return saved;
        });
    }
}
