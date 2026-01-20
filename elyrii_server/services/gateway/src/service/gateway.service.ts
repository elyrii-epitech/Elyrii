import type { Context } from "hono";

export async function proxyRequest(url: string, ctx: Context) {
    try {
        const targetUrl = url + ctx.req.path;
    
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
}
