
export type FetchFunction = (url: string, idToken: string) => Promise<Response>;
export type ResultMapperFunction = (response: Response) => Promise<Response>;