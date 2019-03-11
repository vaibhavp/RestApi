import sqlite3

connection = sqlite3.connect('data.db')
cursor = connection.cursor()

create_table = "CREATE TABLE users(id int, username text, password text)"
cursor.execute(create_table)

user=(1,'vaibhav','vaibhav')
users=[
    (2,'bob','bob'),
    (3,'jak','bob')
]
insert_table ="INSERT INTO users VALUES (?,?,?)"
cursor.execute(insert_table,user)
cursor.executemany(insert_table,users)

select_query="SELECT * from users"
for row in cursor.execute(select_query):
    print(row)

connection.commit()
connection.close()