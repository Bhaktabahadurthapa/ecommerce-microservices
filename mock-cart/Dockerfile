FROM python:3.11-alpine

WORKDIR /app

RUN pip install --no-cache-dir grpcio==1.62.1

COPY mock_cart.py .

EXPOSE 7070

CMD ["python", "mock_cart.py"]
