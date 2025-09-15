producers
  id serial primary key
  company varchar
  email varchar unique
  phone varchar unique
  web varchar
##CONSTRAINT at_least_one_contact_point CHECK (COALESCE((email != '') OR (phone != '') OR (web != ''), FALSE))

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
  options_id int references options

options
  id serial primary key
  name varchar
  config jsonb

stock
  id serial primary key
  count smallint
  product_id int references products
  option_id int references options

fulfillments
  id serial primary key
  received timestamptz not null default now()
  provider varchar
  fulfilled timestamptz
  orderdetails jsonb not null
  materials jsonb not null
  services jsonb not null

services
  id serial primary key
  name varchar not null
  description varchar
  cost smallint not null default 0
  unit varchar not null default 'hr' -- eg hr, piece, box, case
  enabled boolean not null default true
