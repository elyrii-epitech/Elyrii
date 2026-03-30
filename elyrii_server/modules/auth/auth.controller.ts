import { sValidator } from '@hono/standard-validator';
import { describeRoute } from 'hono-openapi';
import { createFactory } from 'hono/factory';
import { registerValidation } from '../../utils/zod.valid';
import AuthRepository from '../../repository/auth.repository';

class AuthController {
    private readonly factory = createFactory();
    private readonly authRepository = new AuthRepository();
    
    constructor() { }
    
    public readonly register = this.factory.createHandlers(
        describeRoute({
            summary: "User Registration",
            description: "Register a new user and automatically log them in.",
            tags: ["Auth"],
            responses: {
                200: { description: "User registered successfully" },
                500: { description: "Registration failed" },
            }
        }),
        sValidator("json", registerValidation),
        async (ctx) => {
            const { email, password, lastName, firstName, age } = ctx.req.valid("json");
            try {
                const existUser = await this.authRepository.findUserByEmail(email);
                if (existUser) {
                    return ctx.json({ message: 'user already exists' }, 400);
                }
                
                const newUser = await this.authRepository.createrUser({
                    email,
                    password,
                    lastName,
                    firstName,
                    age: age ?? 18
                });
            } catch (error) {
                return ctx.json({ message: 'registration failed' }, 500);
            }
            return ctx.json({ message: 'register' });
    })
    
    public readonly login = this.factory.createHandlers((ctx) => {
        return ctx.json({ message: 'login' });
    })
    
    public readonly logout = this.factory.createHandlers((ctx) => {
        return ctx.json({ message: 'logout' });
    })
    
}

export default AuthController;