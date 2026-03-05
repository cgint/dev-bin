import type { TokenProvider, } from "$lib/auth/token_types";
import type { FetchFunction, ResultMapperFunction } from "./fw_types";
/**
 * Runs a fetch function with automatic token refresh on unauthorized responses.
 * @param urlToCall The URL or audience for the token.
 * @param tokenProvider The token provider.
 * @param fetchFn The fetch function to execute.
 * @param resultMapperFn Optional function to map the result.
 * @returns The response from the fetch function.
 */

export async function fetchWithRetry(
    urlToCall: string,
    tokenProvider: TokenProvider,
    fetchFn: FetchFunction,
    resultMapperFn: ResultMapperFunction
): Promise<Response> {
    let idToken = await tokenProvider.getToken(urlToCall);

    try {
        let response = await fetchFn(urlToCall, idToken);

        if (response.status === 401) {
            tokenProvider.clearIdTokenCache(urlToCall);
            idToken = await tokenProvider.getToken(urlToCall);
            response = await fetchFn(urlToCall, idToken);
        }

        if (response.status != 200) {
            throw new Error(`Failed to access ${urlToCall}: ${response.statusText}`);
        }

        return resultMapperFn(response);

    } catch (error) {
        console.error('Error in fetchWithRetry:', error);
        throw error;
    }
} 