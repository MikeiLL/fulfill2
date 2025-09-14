-- Table names are flush left, and column definitions are
-- indented by at least one space or tab. Blank lines and
-- lines beginning with a double hyphen are comments.

producers
  id serial primary key
  company varchar
  email varchar unique
  phone varchar unique
  web varchar
  CONSTRAINT at_least_one_contact_point CHECK (COALESCE((email != '') OR (phone != '') OR (web != ''), FALSE))

users
  id serial primary key
  email varchar not null unique
  displayname varchar not null
  user_level int not null default 1 -- noaccess=0, manager=1, admin=3
  password varchar not null default ''

products
  id serial primary key
  name varchar
  producer_id int references producers

stock
  id serial primary key
  count smallint
  product_id int references products
