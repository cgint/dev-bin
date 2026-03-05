import { ForwardProxy } from '$lib/forwarder/forwardProxy';
import { describe, it, expect, vi, beforeEach, type Mock } from 'vitest';
import type { TokenProvider } from '$lib/auth/token_types';

describe('ForwardProxy', () => {
    let forwardProxy: ForwardProxy;
    const mockForwardFunction = vi.fn();
    const mockResultMapper = vi.fn(async (response: Response) => response);
    const mockTokenProvider: TokenProvider = {
        getToken: vi.fn().mockResolvedValue('mock-token') as Mock,
        clearIdTokenCache: vi.fn()
    };

    beforeEach(() => {
        vi.clearAllMocks(); // Clear mocks before each test
        forwardProxy = new ForwardProxy(mockForwardFunction, mockTokenProvider);
    });

    it('should forward a GET request with correct headers and URL', async () => {
        const mockRequest = new Request('http://example.com/original', {
            method: 'GET',
            headers: { 'X-Custom-Header': 'Value' },
        });
        const destinationUrl = 'http://destination.com/target';
        const mockResponse = new Response('OK', { status: 200 });

        mockForwardFunction.mockResolvedValue(mockResponse);

        const response = await forwardProxy.forward(mockRequest, destinationUrl, mockResultMapper);

        expect(mockTokenProvider.getToken).toHaveBeenCalledWith(destinationUrl);
        expect(mockForwardFunction).toHaveBeenCalledWith(expect.any(Request));

        const proxiedRequest: Request = mockForwardFunction.mock.calls[0][0];
        expect(proxiedRequest.method).toBe('GET');
        expect(proxiedRequest.url).toBe(destinationUrl);
        expect(proxiedRequest.headers.get('X-Custom-Header')).toBe('Value');
        expect(proxiedRequest.headers.get('Authorization')).toBe('Bearer mock-token');
        expect(proxiedRequest.body).toBeNull();
        expect(response).toBe(mockResponse);
    });

    it('should forward a POST request with correct headers, URL, and body', async () => {
        const requestBody = JSON.stringify({ key: 'value' });
        const mockRequest = new Request('http://example.com/original', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Custom-Header': 'Value',
            },
            body: requestBody,
        });
        const destinationUrl = 'http://destination.com/target';
        const mockResponse = new Response('OK', { status: 200 });

        mockForwardFunction.mockResolvedValue(mockResponse);

        const response = await forwardProxy.forward(mockRequest, destinationUrl, mockResultMapper);

        expect(mockTokenProvider.getToken).toHaveBeenCalledWith(destinationUrl);
        expect(mockForwardFunction).toHaveBeenCalledWith(expect.any(Request));

        const proxiedRequest: Request = mockForwardFunction.mock.calls[0][0];
        expect(proxiedRequest.method).toBe('POST');
        expect(proxiedRequest.url).toBe(destinationUrl);
        expect(proxiedRequest.headers.get('X-Custom-Header')).toBe('Value');
        expect(proxiedRequest.headers.get('Authorization')).toBe('Bearer mock-token');
        expect(proxiedRequest.headers.get('Content-Type')).toBe('application/json');
        const forwardedBody = await proxiedRequest.text();
        expect(forwardedBody).toBe(requestBody);
        expect(response).toBe(mockResponse);
    });

    it('should handle 401 by retrying with a fresh token', async () => {
        const mockRequest = new Request('http://example.com/original', { method: 'GET' });
        const destinationUrl = 'http://destination.com/target';

        // Mock getToken to return different tokens on successive calls
        (mockTokenProvider.getToken as Mock)
          .mockResolvedValueOnce('first-token')
          .mockResolvedValueOnce('second-token');

        // Mock forwardFunction to return 401 then 200
        mockForwardFunction.mockResolvedValueOnce(new Response('Unauthorized', { status: 401 }))
                           .mockResolvedValueOnce(new Response('OK', { status: 200 }));

        const response = await forwardProxy.forward(mockRequest, destinationUrl, mockResultMapper);

        // Verify getToken was called twice
        expect(mockTokenProvider.getToken).toHaveBeenCalledTimes(2);
        // Verify clearIdTokenCache was called once
        expect(mockTokenProvider.clearIdTokenCache).toHaveBeenCalledTimes(1);
        // Verify forwardFunction was called twice
        expect(mockForwardFunction).toHaveBeenCalledTimes(2);

        // Check the final response
        expect(response.status).toBe(200);
    });

    it('should throw an error if the retry also fails', async () => {
        const mockRequest = new Request('http://example.com/original', { method: 'GET' });
        const destinationUrl = 'http://destination.com/target';

        // Mock getToken to return different tokens on successive calls,
        // even if it always fails
        (mockTokenProvider.getToken as Mock)
            .mockResolvedValueOnce('first-token')
            .mockResolvedValueOnce('second-token');

        // Mock forwardFunction to always return 401
        mockForwardFunction.mockResolvedValue(new Response('Unauthorized', { status: 401 }));

        await expect(forwardProxy.forward(mockRequest, destinationUrl, mockResultMapper)).rejects.toThrow();

        // Verify getToken was called twice
        expect(mockTokenProvider.getToken).toHaveBeenCalledTimes(2);
        // Verify clearIdTokenCache was called once
        expect(mockTokenProvider.clearIdTokenCache).toHaveBeenCalledTimes(1);
        // Verify forwardFunction was called twice
        expect(mockForwardFunction).toHaveBeenCalledTimes(2);
    });

    it('should use provided forwardFunction', async () => {
        const mockRequest = new Request('http://example.com', { method: 'GET' });
        const destinationUrl = 'http://destination.com';
        const mockResponse = new Response('Mocked Response');

        mockForwardFunction.mockResolvedValue(mockResponse);

        const response = await forwardProxy.forward(mockRequest, destinationUrl, mockResultMapper);

        expect(mockForwardFunction).toHaveBeenCalledWith(expect.any(Request));
        expect(response).toBe(mockResponse);
    });
}); 