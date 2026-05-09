from typing import Generic, TypeVar, Optional, Any
from pydantic import BaseModel, ConfigDict

T = TypeVar("T")

class BaseResponse(BaseModel, Generic[T]):
    """全局统一的API出参结构"""
    code: int = 200
    message: str = "success"
    data: Optional[T] = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "code": 200,
                "message": "success",
                "data": None
            }
        }
    )
