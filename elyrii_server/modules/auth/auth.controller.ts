import { createFactory } from 'hono/factory';

class AuthController {
    private readonly factory = createFactory();
    
    constructor() { }
    
    public readonly register = this.factory.createHandlers((ctx) => {
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