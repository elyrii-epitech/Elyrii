import { Hono } from "hono";

const app = new Hono();

const CHAT_SERVICE_URL = Bun.env.CHAT_SERVICE_URL;
const AUTH_SERVICE_URL = Bun.env.AUTH_SERVICE_URL;

if (!CHAT_SERVICE_URL) {
    throw new Error("CHAT_SERVICE_URL environment variable is required");
}
if (!AUTH_SERVICE_URL) {
    throw new Error("AUTH_SERVICE_URL environment variable is required");
}

app.all("/chat/*", async (ctx) => {
    try {
        const targetUrl = CHAT_SERVICE_URL + ctx.req.path;
    
        const rawReq = ctx.req.raw;
        const headers = new Headers(rawReq.headers);
        
        headers.delete('host');
        headers.delete('content-length');
        
        const response = await fetch(targetUrl, {
            method: rawReq.method,
            body: rawReq.method !== 'GET' && rawReq.method !== 'HEAD' ? rawReq.body : null,
            headers: headers,
            duplex: 'half',
        } as RequestInit);

        return response;
        
    } catch (error) {
        console.error('Proxy error:', error);
        return ctx.json({ 
            error: 'Gateway error', 
            message: error instanceof Error ? error.message : 'Unknown error'
        }, 502);
    }
})

app.all("/auth/*", async (ctx) => {
    try {
        const targetUrl = AUTH_SERVICE_URL + ctx.req.path;

        const rawReq = ctx.req.raw;
        const headers = new Headers(rawReq.headers);
        
        headers.delete('host');
        headers.delete('content-length');
        
        const response = await fetch(targetUrl, {
            method: rawReq.method,
            body: rawReq.method !== 'GET' && rawReq.method !== 'HEAD' ? rawReq.body : null,
            headers: headers,
            duplex: 'half',
        } as RequestInit);

        return response;
        
    } catch (error) {
        console.error('Proxy error:', error);
        return ctx.json({ 
            error: 'Gateway error', 
            message: error instanceof Error ? error.message : 'Unknown error'
        }, 502);
    }
})

export default app;