import sqlite3
from flask_restful import Resource, reqparse

class User:
    def __init__(self,id,username,password):
        self.id= id
        self.username=username
        self.password=password

    @classmethod
    def find_by_username(cls, username):
        connection = sqlite3.connect('data.db')
        cursor = connection.cursor()

        query = "SELECT * from users WHERE username=?"
        result = cursor.execute(query,(username,))
        row = cursor.fetchone()
        if row:
            user = cls(*row)
        else:
            user = None

        connection.close()
        return user


    @classmethod
    def find_by_id(cls,id):
        connection = sqlite3.connect('data.db')
        cursor =  connection.cursor()
        query = "SELECT * from users WHERE id=?"
        result = cursor.execute(query,(id,))
        row = cursor.fetchone()
        if row:
            user = cls(*row)
        else:
            user =None
        connection.close()
        return user

class UserRegister(Resource):
    parser = reqparse.RequestParser()
    parser.add_argument('username', type=str, required=True, help="this filed can not pe empty")
    parser.add_argument('password', type=str, required=True, help="this filed can not pe empty")

    def post(self):
        data = UserRegister.parser.parse_args()

        if(User.find_by_username(data['username'])):
            return {"meassage": "user exist"},201
        else:
            connection = sqlite3.connect('data.db')
            cursor = connection.cursor()
            insert_table = "INSERT INTO users VALUES (NULL,?,?)"
            cursor.execute(insert_table,(data['username'], data['password']))
            connection.commit()
            connection.close()
            return {"message":"User Created successfully."}, 201
