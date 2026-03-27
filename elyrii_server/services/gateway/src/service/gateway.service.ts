import type { Context } from "hono";

/**
 * Proxies an incoming Hono request to a target microservice URL.
 * 
 * @remarks
 * This function forwards the method, headers, and body of the original request to the target URL.
 * It handles the response from the target service and returns it to the client.
 * 
 * @param url - The base URL of the target microservice (e.g., "http://auth-service:3001")
 * @param ctx - The Hono Context object representing the incoming request
 * @returns A Promise that resolves to the Response from the target service
 */
export async function proxyRequest(url: string, ctx: Context) {
    try {
        const incomingUrl = new URL(ctx.req.url);
        const targetUrl = url + incomingUrl.pathname + incomingUrl.search;
    
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
