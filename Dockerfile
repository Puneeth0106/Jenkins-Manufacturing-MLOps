FROM python:3.11

WORKDIR /app

COPY . /app

RUN pip install --no-cache-dir -e . \
    && python -m pipeline.training_pipeline

EXPOSE 5000

ENV FLASK_APP=application.py

CMD ["python", "application.py"]
