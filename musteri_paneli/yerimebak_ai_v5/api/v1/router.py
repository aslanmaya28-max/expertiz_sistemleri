from fastapi import APIRouter
from yerimebak_ai_v5.api.v1.endpoints import analysis, auth, payments, credits, expertiz, personnel, valuation

api_router = APIRouter()
api_router.include_router(analysis.router, tags=["analysis"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(payments.router, prefix="/payments", tags=["payments"])
api_router.include_router(credits.router, prefix="/credits", tags=["credits"])
api_router.include_router(expertiz.router, prefix="/expertiz", tags=["expertiz"])
api_router.include_router(personnel.router, prefix="/personnel", tags=["personnel"])
api_router.include_router(valuation.router, prefix="/valuation", tags=["valuation"])
