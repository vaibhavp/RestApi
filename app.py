import os
from flask import Flask
from flask_restful import  Api
from flask_jwt import JWT


from security import identity,authenticate
from resources.user import UserRegister
from resources.item import Item, ItemsList
from resources.store import Store,StoreList

app= Flask(__name__)
app.secret_key = "vaibhav"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
#app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL','sqlite:///data.db')
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgres://vaibhav:vaibhav@postgres:5432/vaibhav'
api= Api(app)

@app.before_first_request
def create_db():
    db.create_all()

jwt= JWT(app,authenticate,identity) #/auth

api.add_resource(Item,'/item/<string:name>')
api.add_resource(ItemsList,'/items')
api.add_resource(UserRegister,'/register')
api.add_resource(Store,'/store/<string:name>')
api.add_resource(StoreList,'/stores')


if __name__ == '__main__':
    from db import db
    db.init_app(app)

    if app.config['DEBUG']:
        @app.before_first_request
        def create_tables():
            print("inside create_table!!!!")
            db.create_all()
    app.run(port=9000,debug=True,host='0.0.0.0')
