
export interface TokenProvider {
    getToken(audience: string): Promise<string>;
    clearIdTokenCache(audience: string): void;
}
