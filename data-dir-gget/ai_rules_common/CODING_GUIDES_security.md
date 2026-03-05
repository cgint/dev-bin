
# Security

## User data storage (API-Keys, etc.)

# I see my test password "HOLLA" plain text in the cookie.

Cookie content in request header:
```
keys=%7B%22providers%22%3A%7B%22openai%22%3A%22%22%2C%22
anthropic%22%3A%22%22%2C%22gemini%22%3A%22%22%2C%22
mistral%22%3A%22%22%2C%22openrouter%22%3A%22%22%2C%22
test%22%3A%22%22%2C%22chatty%22%3A%22%22%7D%2C%22
searchEngines%22%3A%7B%22perplexity%22%3A%22%22%2C%22
tavily%22%3A%22%22%7D%2C%22
groupApiKey%22%3A%22HOLLA%22%7D  <-- HOLLA
```

although i am stating
```js
// Set the HttpOnly cookie with all API keys
cookies.set(COOKIE_NAME, JSON.stringify(cleanedApiKeys), {
path: COOKIE_PATH,
maxAge: COOKIE_MAX_AGE,
httpOnly: true,
secure: true,
sameSite: 'strict'
});
```

i am using svelte kit

### Questions

- is this to be expected ?
- am i wrong to expect that the cookie contents is encrpyted over the wire (in addition to HTTPS) when secure: true is set

Seeing plaintext values like "HOLLA" in cookies despite using `httpOnly` and `secure` flags is expected behavior. Here's why:

### 1. Cookie Visibility in Browser

- **HttpOnly prevents JavaScript access**, but doesn't encrypt cookie contents[^1_1][^1_5]. The value remains visible in:
    - Browser DevTools → Application → Cookies
    - Network tab for HTTPS requests
- **Secure flag only ensures transmission over HTTPS** - it doesn't encrypt the cookie value itself[^1_2][^1_6]


### 2. Encryption Scope

- **HTTPS encrypts data in transit**, not at rest[^1_6]. The cookie value is:
    - Encrypted during network transmission
    - Stored in plaintext in browser storage
- **Secure flag** ensures the cookie is **never sent over unencrypted HTTP**[^1_2][^1_6]


### Security Recommendations

1. **Avoid sensitive data in cookies**:

```js
// Instead of storing credentials directly:
cookies.set('session', encryptedToken, { httpOnly: true, secure: true })
```

2. **Use server-side sessions** for sensitive data
3. **Add content encryption** if you must store sensitive data:

```js
import { encrypt } from 'your-crypto-lib'
const encryptedValue = encrypt(JSON.stringify(keys), secret)
cookies.set('keys', encryptedValue, { httpOnly: true, secure: true })
```


### SvelteKit-Specific Considerations

Your implementation is correct for SvelteKit's cookie handling[^1_4], but remember:

- HttpOnly cookies are still visible in browser storage
- Secure flag only affects transmission security
- For API keys, consider using signed cookies or backend storage with session IDs

The observed behavior is normal - cookie flags provide transport and script access security, not value encryption. For sensitive data like API keys, consider alternative storage mechanisms like secure backend sessions.

<div style="text-align: center">⁂</div>

[^1_1]: https://cookie-script.com/documentation/httponly-cookies

[^1_2]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies

[^1_3]: https://security.stackexchange.com/questions/186441/any-reason-not-to-set-all-cookies-to-use-httponly-and-secure

[^1_4]: https://www.loopwerk.io/articles/2021/sveltekit-cookies-tokens/

[^1_5]: https://www.wisp.blog/blog/understanding-httponly-cookies-and-security-best-practices

[^1_6]: https://www.invicti.com/learn/cookie-security-flags/

[^1_7]: https://rodneylab.com/sveltekit-session-cookies/

[^1_8]: https://www.pivotpointsecurity.com/securing-web-cookies-secure-flag/

[^1_9]: https://svelte.dev/tutorial/kit/cookies

[^1_10]: https://lucia-auth.com/sessions/cookies/sveltekit

[^1_11]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies

[^1_12]: https://stackoverflow.com/questions/73669427/i-can-view-httponly-cookies-in-browser

[^1_13]: https://www.reddit.com/r/webdev/comments/11dwpci/what_is_the_point_of_an_httponly_cookie/

[^1_14]: https://security.stackexchange.com/questions/174702/are-httponly-cookies-secure-enough-for-implementing-remember-me-functionality

[^1_15]: https://community.spiceworks.com/t/is-it-possible-to-access-http-only-cookie-values-with-javascript/221902

[^1_16]: https://dev.to/costamatheus97/battle-of-the-cookies-regular-cookies-vs-http-only-1n0a

[^1_17]: https://stackoverflow.com/questions/73578301/can-you-briefly-explain-the-difference-between-httponly-cookies-and-normal-cooki

[^1_18]: https://bito.ai/resources/httponly-cookie-javascript-javascript-explained/

[^1_19]: https://wiki.selfhtml.org/wiki/Cookie/sichere_Cookies

[^1_20]: https://security.stackexchange.com/questions/53359/are-httponly-cookies-submitted-via-xmlhttprequest-with-withcredentials-true

[^1_21]: https://www.feroot.com/blog/3-important-things-to-know-about-cookie-security/

[^1_22]: https://blog.codinghorror.com/protecting-your-cookies-httponly/

[^1_23]: https://stackoverflow.com/questions/19862854/cookie-security-when-passed-over-ssl

[^1_24]: https://stackoverflow.com/questions/39384615/if-all-our-sites-are-secure-https-is-setting-the-secure-flag-on-cookies-red

[^1_25]: https://www.cookieyes.com/knowledge-base/cookies-101/what-is-a-secure-cookie/

[^1_26]: https://en.wikipedia.org/wiki/HTTP_cookie

[^1_27]: https://en.wikipedia.org/wiki/Secure_cookie

[^1_28]: https://owasp.org/www-community/controls/SecureCookieAttribute

[^1_29]: https://securinglaravel.com/security-tip-the-cookie-secure-flag/

[^1_30]: https://community.f5.com/discussions/technicalforum/secure-flag-for-cookie/267340

[^1_31]: https://www.zaproxy.org/docs/alerts/10011/

[^1_32]: https://michaelzanggl.com/articles/web-security-cookies/

[^1_33]: https://dev.to/theether0/sveltekit-changes-session-and-cookies-enb

[^1_34]: https://stackoverflow.com/questions/70742213/authenticating-sveltekit-with-jwt-api-using-cookies

[^1_35]: https://blog.ethercorps.io/blog/sveltekit-changes-session-and-cookies-enb

[^1_36]: https://blacknerd.dev/how-to-build-custom-authentication-in-sveltekit-a-session-and-cookie-overview

[^1_37]: https://www.reddit.com/r/sveltejs/comments/xs68ag/sveltekit_authentication_using_cookies/

[^1_38]: https://github.com/sveltejs/kit/issues/7564

[^1_39]: https://github.com/sveltejs/kit/issues/6604

[^1_40]: https://joyofcode.xyz/sveltekit-authentication-using-cookies

[^1_41]: https://matteogassend.com/blog/end-to-end-sveltekit/

[^1_42]: https://stackoverflow.com/questions/77916952/cookies-behavior-in-script-tag-and-fetch-inside-a-server-ts-file-in-svel

[^1_43]: https://news.ycombinator.com/item?id=33986555

[^1_44]: https://www.edureka.co/community/292256/how-to-read-a-httponly-cookie-using-javascript

[^1_45]: https://www.infosecinstitute.com/resources/general-security/securing-cookies-httponly-secure-flags/

[^1_46]: https://stackoverflow.com/questions/8064318/how-to-read-a-httponly-cookie-using-javascript

[^1_47]: https://security.stackexchange.com/questions/200964/modifying-an-httponly-cookie-before-sending-the-request

[^1_48]: https://security.stackexchange.com/questions/140940/can-a-secure-cookie-be-set-from-an-insecure-http-connection-if-so-why-is-it-al

[^1_49]: https://ruptura-infosec.com/security-advice/cookie-security-flags/

[^1_50]: https://wirekat.com/understanding-http-cookie-flags/

[^1_51]: https://stackoverflow.com/questions/6195144/does-ssl-also-encrypt-cookies

[^1_52]: https://www.reddit.com/r/sveltejs/comments/13qiosk/how_do_i_set_cookies_when_authenticating_via_an/

[^1_53]: https://github.com/pixelmund/svelte-kit-cookie-session

[^1_54]: https://www.linkedin.com/pulse/sveltekit-session-cookies-going-httponly-rodney-lab-1e

[^1_55]: https://blog.logrocket.com/authentication-svelte-using-cookies/

