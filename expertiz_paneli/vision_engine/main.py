"""
Vision Engine - FastAPI Main Application
Exposes /analyze endpoint for Flutter integration
"""

import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

from .models import AnalysisRequest, AnalysisResponse, ErrorResponse
from .manager import get_manager

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup/shutdown"""
    logger.info("🚀 Vision Engine starting up...")
    yield
    logger.info("👋 Vision Engine shutting down...")


# Initialize FastAPI app
app = FastAPI(
    title="Vision Engine API",
    description="YerimeBak Expertiz System - Multi-Source Market Data Analysis with AI Commentary",
    version="1.0.0",
    lifespan=lifespan
)

# 🔒 DÜZELTİLDİ (B19): CORS * + credentials=True -> Güvenli hale getirildi
# allow_credentials=True ile allow_origins=["*"] birlikte KULLANILAMAZ.
# Bu tarayıcı tarafından reddedilir ve güvenlik açığı oluşturur.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://yerimebak.com.tr",
        "https://app.yerimebak.com.tr",
        "https://api.yerimebak.com.tr",
    ],
    allow_credentials=False,  # credentials=True ise origins=["*"] olamaz
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Content-Type",
        "Authorization",
        "X-Request-ID",
        "X-CSRF-Token",
    ],
    expose_headers=[
        "Content-Type",
        "X-Request-ID",
    ],
    max_age=3600,  # Preflight cache 1 saat
)


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "online",
        "service": "Vision Engine API",
        "version": "1.0.0",
        "endpoints": {
            "analyze": "/analyze",
            "health": "/health"
        }
    }


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "google_api_key": bool(os.getenv("GOOGLE_API_KEY")),
        "environment": os.getenv("ENVIRONMENT", "development")
    }


@app.post(
    "/analyze",
    response_model=AnalysisResponse,
    summary="Analyze vehicle market value",
    description="Complete vehicle analysis with multi-source data collection, statistical analysis, and AI commentary"
)
async def analyze_vehicle(request: AnalysisRequest):
    """
    Analyze vehicle market value
    
    This endpoint performs:
    1. Multi-source data collection (Arabam, VavaCars, Borusan)
    2. Core Engine statistical analysis (IQR outlier removal)
    3. Image analysis (if images provided)
    4. AI Commentary (Gemini 1.5 Flash)
    5. Fair value estimation with adjustments
    
    Returns complete AnalysisResponse with all metrics
    """
    
    try:
        logger.info(f"📥 Received analysis request: {request.brand} {request.model} {request.year}")
        
        # Get manager and perform analysis
        manager = get_manager()
        response = await manager.analyze(request)
        
        if not response.success:
            raise HTTPException(
                status_code=400,
                detail=response.final_recommendation
            )
        
        logger.info(f"✅ Analysis completed: {response.estimated_value:,.0f} TL")
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Analysis error: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Internal server error: {str(e)}"
        )


@app.post("/analyze/quick")
async def analyze_quick(request: AnalysisRequest):
    """
    Quick analysis endpoint (lightweight version)
    Returns only essential metrics
    """
    
    try:
        manager = get_manager()
        response = await manager.analyze(request)
        
        # Return lightweight response
        return {
            "success": response.success,
            "estimated_value": response.estimated_value,
            "value_range": response.value_range,
            "confidence_score": response.core_metrics.confidence_score,
            "recommendation": response.final_recommendation,
            "processing_time_ms": response.processing_time_ms
        }
        
    except Exception as e:
        logger.error(f"❌ Quick analysis error: {e}")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )


@app.get("/stats")
async def get_stats():
    """Get system statistics"""
    return {
        "system": "Vision Engine",
        "version": "1.0.0",
        "features": {
            "multi_source_collection": True,
            "statistical_analysis": True,
            "ai_commentary": bool(os.getenv("GOOGLE_API_KEY")),
            "image_analysis": True,
            "factor_matching": True
        },
        "data_sources": [
            "Arabam (Piyasa)",
            "VavaCars (Nakit Alt Sınır)",
            "Borusan Next (Premium Üst Sınır)"
        ]
    }


# Exception handlers
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error_type": "InternalServerError",
            "error_message": str(exc)
        }
    )


if __name__ == "__main__":
    import uvicorn
    
    # Run server
    uvicorn.run(
        "vision_engine.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )