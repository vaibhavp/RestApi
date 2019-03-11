from flask import Flask
from flask_restful import  Api
from flask_jwt import JWT
from item import Item, ItemsList

from security import identity,authenticate
from user import UserRegister

app= Flask(__name__)
app.secret_key = "vaibhav"
api= Api(app)

jwt= JWT(app,authenticate,identity) #/auth

api.add_resource(Item,'/item/<string:name>')
api.add_resource(ItemsList,'/items')
api.add_resource(UserRegister,'/register')


if __name__ == '__main__':
    app.run(port=8080, debug=True)