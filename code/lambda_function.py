from fastapi import APIRouter, FastAPI, HTTPException, Path, Query
from typing import Optional
from mangum import Mangum

app = FastAPI()
lambda_handler = Mangum(app)

router = APIRouter(prefix="/api/users")

@router.get("/health-check")
async def health_check():
    return {"message": "Service is up and running - health check passed!"}

@router.get("/")
async def get_users(id_like: Optional[str] = Query(None, description="Search users with IDs that contain the specified value")):
    return {
        "message": f"This is the function to get all users, optionally filtered by id_like: {id_like}"
    }

@router.get("/{id}")
async def get_user(id: str = Path(..., description="ID of the user to retrieve")):
    return {"message": f"This is the function to get a user with ID: {id}"}

@router.post("/")
async def create_user():
    return {"message": "This is the function to create a new user."}

@router.patch("/{id}")
async def update_user(id: str):
    return {"message": f"This is the function to partially update a user with ID: {id}"}

@router.delete("/{id}")
async def delete_user(id: str = Path(..., description="ID of the user to delete")):
    return {"message": f"This is the function to delete a user with ID: {id}"}

app.include_router(router)
