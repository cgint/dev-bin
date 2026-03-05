import type { TokenProvider } from "$lib/auth/types";
import { fetchWithRetry } from "$lib/forwarder/fetchWithRetry";

export class ForwardProxy {
    private forwardFunction: (request: Request) => Promise<Response>;
    private tokenProvider: TokenProvider;

    constructor(forwardFunction: (request: Request) => Promise<Response>, tokenProvider: TokenProvider) {
        this.forwardFunction = forwardFunction;
        this.tokenProvider = tokenProvider;
    }
    
    async forward(request: Request, destinationUrl: string, myResultMapper: (response: Response) => Promise<Response>, additionalHeaders: Headers = new Headers()) {
        const forwardMethod = request.method;
        const forwardBody = request.method !== 'GET' && request.method !== 'HEAD' ? await request.blob() : null;
        const forwardHeaders = new Headers(request.headers);
        forwardHeaders.delete('Authorization');
        additionalHeaders.forEach((value, key) => {
            forwardHeaders.set(key, value);
        });

        // using 'this.forwardFunction' would not work on cloudflare pages
        const forwardFunction = this.forwardFunction;

        try {
            const fetchFunction = async (url: string, idToken: string): Promise<Response> => {
                const allHeaders = new Headers(forwardHeaders);
                allHeaders.set('Authorization', `Bearer ${idToken}`);
                const proxiedRequest = new Request(url, {
                    method: forwardMethod,
                    headers: allHeaders,
                    body: forwardBody
                });

                return forwardFunction(proxiedRequest);
            };
            return await fetchWithRetry(destinationUrl, this.tokenProvider, fetchFunction, myResultMapper);

        } catch (err) {
            console.error('Error in calling cloud run service:', err);
            throw err;
        }
    }
    
    
}