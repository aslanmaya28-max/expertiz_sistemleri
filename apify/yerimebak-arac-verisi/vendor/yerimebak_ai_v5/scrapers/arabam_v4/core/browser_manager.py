# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Browser Manager
Browser lifecycle management with anti-detection
Letgo v4.0 pattern - 6 browser args + 5 JS scripts
"""

import asyncio
from typing import Optional
from playwright.async_api import async_playwright, Browser, BrowserContext, Page, Playwright
from .config.settings import (
    USER_AGENT,
    DEFAULT_VIEWPORT,
    DEFAULT_LOCALE,
    DEFAULT_TIMEZONE,
    DEFAULT_GEOLOCATION,
    HTTP_HEADERS,
    BROWSER_ARGS,
    PAGE_LOAD_TIMEOUT,
    STEALTH_SCRIPTS,
)


class BrowserManager:
    """
    Browser Manager - Anti-detection with 6 browser args + 5 JS scripts
    
    Letgo v4.0 pattern implementation:
    - 6 browser arguments for anti-detection
    - 5 JS stealth scripts for fingerprinting protection
    - Human-like browser context
    - Resource management
    """
    
    def __init__(self, headless: bool = False):
        """
        Initialize browser manager
        
        Args:
            headless: Run browser in headless mode (default: False)
        """
        self.headless = headless
        self.playwright: Optional[Playwright] = None
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self._is_initialized = False
    
    async def initialize(self) -> None:
        """
        Initialize playwright and browser
        
        Launch browser with 6 anti-detection arguments
        """
        if self._is_initialized:
            return
        
        self.playwright = await async_playwright().start()
        
        # Launch browser with 6 anti-detection args
        self.browser = await self.playwright.chromium.launch(
            headless=self.headless,
            args=BROWSER_ARGS
        )
        
        self._is_initialized = True
    
    async def create_context(self, **kwargs) -> BrowserContext:
        """
        Create browser context with anti-fingerprinting
        
        Args:
            **kwargs: Additional context options
            
        Returns:
            BrowserContext instance
        """
        if not self._is_initialized:
            await self.initialize()
        
        # Merge default settings with custom settings
        context_options = {
            'user_agent': USER_AGENT,
            'viewport': DEFAULT_VIEWPORT,
            'locale': DEFAULT_LOCALE,
            'timezone_id': DEFAULT_TIMEZONE,
            'geolocation': DEFAULT_GEOLOCATION,
            'permissions': ['geolocation'],
            'extra_http_headers': HTTP_HEADERS,
        }
        context_options.update(kwargs)
        
        self.context = await self.browser.new_context(**context_options)
        
        # Add 5 JS stealth scripts
        await self.context.add_init_script(STEALTH_SCRIPTS)
        
        return self.context
    
    async def create_page(self) -> Page:
        """
        Create new page with default timeout
        
        Returns:
            Page instance
        """
        if self.context is None:
            await self.create_context()
        
        page = await self.context.new_page()
        
        # Set default timeout (convert seconds to milliseconds)
        page.set_default_timeout(PAGE_LOAD_TIMEOUT * 1000)
        
        return page
    
    async def close(self) -> None:
        """
        Close browser and cleanup
        """
        if self.context:
            await self.context.close()
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
        
        self._is_initialized = False
    
    @property
    def is_initialized(self) -> bool:
        """
        Check if browser is initialized
        
        Returns:
            bool: True if initialized
        """
        return self._is_initialized
    
    async def __aenter__(self):
        """Async context manager entry"""
        await self.initialize()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.close()
