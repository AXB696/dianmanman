from fastapi import Request, status
from fastapi.responses import JSONResponse
import logging

logger = logging.getLogger(__name__)

class BusinessException(Exception):
    def __init__(self, code: int, message: str):
        self.code = code
        self.message = message

async def global_exception_handler(request: Request, exc: Exception):
    """
    兜底全局异常处理，所有未捕获异常返回标准的 500 JSON结构
    """
    logger.error(f"Global unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "code": status.HTTP_500_INTERNAL_SERVER_ERROR,
            "message": "服务器端由于未知原因感到不适 (Internal Server Error)",
            "data": None
        }
    )

async def business_exception_handler(request: Request, exc: BusinessException):
    """
    处理预期内的业务异常
    """
    return JSONResponse(
        status_code=status.HTTP_200_OK,  # 业务异常通常HTTP状态也是200，用内部code区分
        content={
            "code": exc.code,
            "message": exc.message,
            "data": None
        }
    )
