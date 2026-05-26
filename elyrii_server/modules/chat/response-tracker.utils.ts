import { EventEmitter } from "node:events";

class ResponseTracker extends EventEmitter {
    async waitForResponse(requestId: string, timeout = 30000): Promise<string> {
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                this.removeListener(requestId, handler);
                reject(new Error(`Timeout waiting for AI response (${requestId})`));
            }, timeout);

            const handler = (response: string) => {
                clearTimeout(timer);
                resolve(response);
            };

            this.once(requestId, handler);
        });
    }

    resolveResponse(requestId: string, response: string) {
        this.emit(requestId, response);
    }
}

export const aiResponseTracker = new ResponseTracker();
