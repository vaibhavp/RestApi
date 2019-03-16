from flask_restful import Resource, reqparse
from flask_jwt import jwt_required
from models.item import ItemModel

class Item(Resource):
    parse = reqparse.RequestParser()
    parse.add_argument('price',
                       type=float,
                       required=True,
                       help="This filed can not be blank")

    parse.add_argument('store_id',
                       type=int,
                       required=True,
                       help="Every Item should have store id")

    @jwt_required()
    def get(self,name):
        item = ItemModel.find_by_name(name)
        if item:
            return item.json()
        return {'message': "Item not found"}, 404

    def post(self,name):
        if ItemModel.find_by_name(name):
            return {'message': "An item with name {} already exist".format(name)}, 400
        data = Item.parse.parse_args()
        item =ItemModel(name, **data)
        try:
            item.save_to_db()
        except:
            return {"message": "Error occurred while insert "}, 500
        return item.json(), 201


    def delete(self,name):
        item = ItemModel.find_by_name(name)
        if item:
            item.delete_from_db()

        return {'message':'Item deleted'}, 200

    def put(self,name):
        data= Item.parse.parse_args()
        item = ItemModel.find_by_name(name)

        if item is None:
            item = ItemModel(name,**data)
        else:
            item.price=data['price']

        item.save_to_db()
        return item.json()


class ItemsList(Resource):
    def get(self):
        return {"item":list(map(lambda x:x.json(), ItemModel.query.all()))}
