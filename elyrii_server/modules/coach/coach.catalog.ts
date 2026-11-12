import {coachPathSchema} from "./coach.journey-contracts";

// Editorial content matches the shipped Flutter catalogue. Enrollments keep
// their own snapshot so publishing a later version cannot change a live step.
export const COACH_CATALOG = [
    {pathId: "connection-small-steps", contentVersion: 2, title: "Garder le contact",
        description: "Préparer un message et choisir comment reprendre contact.", topic: "connection", steps: [
            {stepId: "connection-prepare", title: "Penser à une personne",
                instructions: "Choisis une personne à qui tu aimerais donner des nouvelles. Note quelques idées dans le Journal si cela t’aide.",
                durationMinutes: 2, action: {kind: "journal", prompt: "Une personne à qui je pense"}},
            {stepId: "connection-message", title: "Préparer quelques mots",
                instructions: "Prépare un message pour une personne de ton choix. L’envoi est facultatif.",
                durationMinutes: 3, action: {kind: "none"}},
            {stepId: "connection-gratitude", title: "Remarquer un petit geste",
                instructions: "Note un geste qui a compté pour toi. Contacter la personne est facultatif.",
                durationMinutes: 2, action: {kind: "journal", prompt: "Un petit geste qui a compté pour moi"}},
        ]},
    {pathId: "calm-at-your-pace", contentVersion: 2, title: "Faire une pause",
        description: "Faire un exercice de respiration, puis écrire quelques mots.", topic: "calm", steps: [
            {stepId: "calm-natural-breath", title: "Observer le souffle",
                instructions: "Assieds-toi comme tu es à l’aise. Observe ton souffle comme il vient, sans chercher à le changer. Tu peux garder les yeux ouverts, arrêter à tout moment ou simplement remarquer tes appuis si le souffle te met mal à l’aise.",
                durationMinutes: 3, action: {kind: "meditation", programId: "mindful-breathing", durationMinutes: 3}},
            {stepId: "calm-free-writing", title: "Écriture libre", instructions: "Écris ce qui te vient dans le Journal.",
                durationMinutes: 5, action: {kind: "journal", prompt: "Écriture libre"}},
        ]},
    {pathId: "sleep-evening-pause", contentVersion: 2, title: "Une pause avant la nuit",
        description: "Revenir sur ta journée et faire un scan corporel avant de te coucher.", topic: "sleep", steps: [
            {stepId: "sleep-gratitudes", title: "Les petites choses du jour",
                instructions: "Repense à un bon moment de ta journée. Note-le dans le Journal ou garde-le en tête.",
                durationMinutes: 3, action: {kind: "journal", prompt: "Un bon moment de la journée"}},
            {stepId: "sleep-body-scan", title: "Parcourir les sensations",
                instructions: "Assieds-toi ou allonge-toi confortablement. Porte ton attention sur les sensations du visage jusqu’aux pieds, sans chercher à les changer. Tu peux rester sur une zone confortable, garder les yeux ouverts ou arrêter quand tu le souhaites.",
                durationMinutes: 5, action: {kind: "meditation", programId: "body-scan", durationMinutes: 5}},
        ]},
].map(path => coachPathSchema.parse(path));
