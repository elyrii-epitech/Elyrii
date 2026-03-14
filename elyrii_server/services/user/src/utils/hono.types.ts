import { type TokenPayload } from "./jwt.utils";

export type HonoEnv = {
    Variables: {
        user: TokenPayload;
    }
}
