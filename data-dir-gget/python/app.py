from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl

from constants import access_pwd

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def verify_password(request: Request) -> None:
    if "password" not in request.headers:
        print("Unauthorized request. No password provided!")
        raise HTTPException(status_code=401, detail="Unauthorized")
    pwd = request.headers.get("password", "")
    if pwd != access_pwd:
        print("Unauthorized request. Password did not match!")
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/ping")
async def ping(request: Request) -> Response:
    print("Headers:", dict(request.headers))
    return Response(content="pong", status_code=200)

class RSSFeedRequest(BaseModel):
    url: HttpUrl
    