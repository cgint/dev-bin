if (!import.meta.env.SSR) {
    throw new Error('This section has to run in SSR mode');
}

import * as jose from 'jose';
import type { TokenProvider } from './token_types';

/**
 * Make sure to set the environment variables in the .env file and via 'npx wrangler pages secret put'
 */
const GSA_AUTH_DEBUG: boolean = import.meta.env.VITE_GSA_AUTH_DEBUG || false;
const GSA_CLIENT_EMAIL: string = import.meta.env.VITE_GSA_CLIENT_EMAIL;
const GSA_PRIVATE_KEY_RAW: string = import.meta.env.VITE_GSA_PRIVATE_KEY;
// Replace escaped newlines with actual newlines and clean up the key
// and remove any surrounding quotes if present
const GSA_PRIVATE_KEY: string = GSA_PRIVATE_KEY_RAW.replace(/\\n/g, '\n').replace(/^['"]|['"]$/g, '');
const GSA_PRIVATE_KEY_ID: string = import.meta.env.VITE_GSA_PRIVATE_KEY_ID;
// const GSA_PROJECT_ID: string = import.meta.env.VITE_GSA_PROJECT_ID;

const GSA_AUTH_JWT_EXPIRATION_TIME_SECONDS: number = 3600; // 1 hour

/**
 * Developed against "jose": "5.*"
 */

/**
 *   Usage example:
 *      const backend_url = CLOUD_RUN_SERVICE_URL;
 *      const cloudRunIdToken = await getGoogleAuthService().getIdToken(backend_url);
 *      const response = await fetch(backend_url, {
 *          method: 'GET',
 *          headers: {
 *              'Authorization': `Bearer ${cloudRunIdToken}`,
 *              'Content-Type': 'application/json'
 *          }
 *      });
 */
type GoogleAuthServiceCacheEntry = {
    idToken: string;
    expiresAt: number;
}
class GoogleAuthService implements TokenProvider {
    private TOKEN_URI = "https://www.googleapis.com/oauth2/v4/token";
    private email: string;
    private privateKey: string;
    private privateKeyId: string;
    private idTokenByAudienceCache: Map<string, GoogleAuthServiceCacheEntry> = new Map();
    private idTokenByAudienceCacheTTLSec: number = GSA_AUTH_JWT_EXPIRATION_TIME_SECONDS;

    constructor(email: string, privateKey: string, privateKeyId: string) {
        this.email = email;
        this.privateKey = privateKey;
        this.privateKeyId = privateKeyId;
    }

    /**
     * @param targetAudience The target audience for the ID token. Usually the URL of the backend service.
     * @returns The ID token. To be used e.g. as http-header 'Authorization': `Bearer ${cloudRunIdToken}`
     */
    async getIdToken(targetAudience: string): Promise<string> {
        const cacheEntry = this.idTokenByAudienceCache.get(targetAudience);
        if(!cacheEntry && GSA_AUTH_DEBUG) {
            console.log('No cache entry for', this.email, 'and target audience', targetAudience);
        }
        if(cacheEntry && GSA_AUTH_DEBUG) {
            console.log('Cache entry for', this.email, 'and target audience', targetAudience, ' expires at', cacheEntry.expiresAt, 'now is', Date.now());
        }
        if (cacheEntry && cacheEntry.expiresAt > Date.now()) {
            if (GSA_AUTH_DEBUG) {
                console.log('Using cached ID token for', this.email, 'and target audience', targetAudience, 'being', this.getPrivateKeySecured(cacheEntry.idToken));
            }
            return cacheEntry.idToken;
        }
        const idToken = await this.getIdTokenFetchFresh(targetAudience);
        const expiresAt = Date.now() + this.idTokenByAudienceCacheTTLSec * 1000;
        this.idTokenByAudienceCache.set(targetAudience, { idToken, expiresAt });
        return idToken;
    }

    private async getIdTokenFetchFresh(targetAudience: string): Promise<string> {
        let googleCloudAccessToken;
        try {
            if (GSA_AUTH_DEBUG) {
                console.log('About to acquire ID token for', this.email, 'and target audience', targetAudience, 'and private key', this.getPrivateKeySecured(this.privateKey));
            }
            const googleCloudSaIdToken = await this.generateAccessTokenRequestJWT(targetAudience);
            googleCloudAccessToken = await this.generateIdTokenWithOAuthRequest(googleCloudSaIdToken);
            if (GSA_AUTH_DEBUG) {
                console.log('Successfully acquired ID token for', this.email, 'and target audience', targetAudience, 'being', this.getPrivateKeySecured(googleCloudAccessToken));
            }
        } catch (e) {
            console.log('Error', e);
            console.log('Error stack:', e instanceof Error ? e.stack : 'No stack trace available');
            throw e;
        }

        return googleCloudAccessToken;
    }

    private async generateAccessTokenRequestJWT(targetAudience: string): Promise<string> {
        const algorithm = "RS256";
        const now_sec = Math.floor(Date.now() / 1000);
        const privateKey = await jose.importPKCS8(this.privateKey, algorithm);
        const jwt = new jose.SignJWT({ "aud": this.TOKEN_URI, "target_audience": targetAudience, "iss": this.email, "sub": this.email, "exp": now_sec + this.idTokenByAudienceCacheTTLSec })
        .setProtectedHeader({ "alg": algorithm, "typ": "JWT", "kid": this.privateKeyId })
        .setIssuedAt(now_sec) // Add issued at claim
        .setNotBefore(now_sec); // Add not before claim

        return jwt.sign(privateKey);
    }

    private async generateIdTokenWithOAuthRequest(idToken: string): Promise<string> {
        // Make POST request to Google's OAuth2 token endpoint
        const response = await fetch(this.TOKEN_URI, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: new URLSearchParams({
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': idToken
            })
        });

        if (!response.ok) {
            console.log('error-response', response);
            console.log('error-response.body', await response.text());
            throw new Error(`Failed to get access token: ${response.statusText}`);
        }

        const data = await response.json();
        return data.id_token;
    }

    private getPrivateKeySecured(privateKeyString: string): string {
        return privateKeyString.slice(0, 30) + "..." + privateKeyString.slice(-30);
    }
    public async getToken(audience: string): Promise<string> {
        return this.getIdToken(audience);
    }

    /**
     * Clears the cached ID token for a specific target audience
     * @param targetAudience The target audience whose token should be cleared
     */
    public clearIdTokenCache(targetAudience: string): void {
        this.idTokenByAudienceCache.delete(targetAudience);
    }
}

let googleAuthService: GoogleAuthService | null = null;

// Export a singleton instance with the environment variables
export function getGoogleAuthService(): GoogleAuthService {
    if (!googleAuthService) {
        googleAuthService = new GoogleAuthService(GSA_CLIENT_EMAIL, GSA_PRIVATE_KEY, GSA_PRIVATE_KEY_ID);
    }
    return googleAuthService;
}

