import { EventEmitter } from "node:events";

export class ResponseTracker extends EventEmitter {
    // Register before publishing: a fast worker may respond before send() resolves.
    request(requestId: string, dispatch: () => Promise<unknown>, timeout = 30000): Promise<string> {
        return new Promise((resolve, reject) => {
            const cleanup = () => {
                clearTimeout(timer);
                this.removeListener(requestId, handler);
            };
            const timer = setTimeout(() => {
                cleanup();
                reject(new Error(`Timeout waiting for AI response (${requestId})`));
            }, timeout);

            const handler = (response: string) => {
                cleanup();
                resolve(response);
            };

            this.once(requestId, handler);
            Promise.resolve().then(dispatch).catch((error) => {
                cleanup();
                reject(error);
            });
        });
    }

    resolveResponse(requestId: string, response: string) {
        this.emit(requestId, response);
    }
}

export const aiResponseTracker = new ResponseTracker();
