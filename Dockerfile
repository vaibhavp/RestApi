From python:3.5-alpine
RUN apk update && apk add postgresql-dev gcc python3-dev musl-dev
COPY . /items-rest
WORKDIR /items-rest
RUN pip install -r requirements.txt
ENV DATABASE_URL=postgres://vaibhav:vaibhav@postgres:5432/vaibhav
ENTRYPOINT ["python","app.py"]
EXPOSE 9000
