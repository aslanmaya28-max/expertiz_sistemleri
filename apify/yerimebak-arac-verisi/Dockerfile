# Apify'in Playwright + Chromium iceren resmi Python imaji
FROM apify/actor-python-playwright:3.12

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . ./
RUN python3 -m compileall -q src vendor

CMD ["python3", "-m", "src"]
