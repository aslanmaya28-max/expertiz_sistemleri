import logging
import sys

# Configure logging to stdout
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

# Global logger instance
logger = logging.getLogger("yerimebak_ai")

def get_logger(name: str = "yerimebak_ai"):
    """Get a named logger"""
    return logging.getLogger(name)
