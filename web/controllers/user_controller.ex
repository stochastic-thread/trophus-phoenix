defmodule Trophus.UserController do
  use Trophus.Web, :controller

  alias Trophus.User

  plug :scrub_params, "user" when action in [:create, :update]
  plug :action

  def jsonify(conn, %{"id" => id}) do
    Trophus.Repo.all(Trophus.User)
    |> Enum.filter fn(x) -> x.id == id end
    |> Poison.encode!
    render(conn)
  end

  def get_images(conn, params) do
    IO.inspect conn
    user = Trophus.Repo.get(Trophus.User, params["user_id"])
    agent = Instagrab.start_link(user.instagram_token)
    :timer.sleep(3000)
    list = Agent.get(agent, fn x -> x end)
    json conn, %{images: list}
  end

  def add_bank_token(conn, params) do
    IO.inspect "You are seeing the params from the bank account token POST request"
    IO.inspect params
    # params["address1"]
    # params["address2"]
    # params["address_city"]
    # params["address_state"]
    # params["address_zip"]
    year =              params["dob1"]
    month =             params["dob2"]
    date =              params["dob3"]
    first_name =        params["first_name"]
    last_name =         params["last_name"]
    tos_acceptance_ip = params["ip_address"]
    token =             params["token"]
    user_id =           params["user_id"]
    ip =                params["client_ip"]
    t =            :os.timestamp()
    
    {:ok, a} = t |> Tuple.to_list |> Enum.fetch 0
    {:ok, b} = t |> Tuple.to_list |> Enum.fetch 1
    {:ok, c} = t |> Tuple.to_list |> Enum.fetch 2
    
    unix_time = (Integer.to_string a)<>(Integer.to_string b)<>(Integer.to_string c)

    HTTPotion.start
    content_type = "application/x-www-form-urlencoded"
    auth = "Bearer sk_test_aqQo51A1cGQEk09BCaCGmkYZ"
    user = Trophus.Repo.get(Trophus.User, params["user_id"])
    acct = user.connect_id
    stripe_customers_url = "https://api.stripe.com/v1/accounts/"<>acct
    headers = ["Content-type": content_type, "Authorization": auth]
    x = "external_account="<>params["token"]<>"&"
    y = "legal_entity[first_name]="<>first_name<>"&"
    y2 = "legal_entity[last_name]="<>last_name
    y3 = "tos_acceptance"

    payload_content = x<>y<>y2
    payload = [body: payload_content, headers: headers]
    response = HTTPotion.post stripe_customers_url, payload
    IO.inspect response
  end

  def auth_callback(conn, params) do
    token = Instagram.get_token!(%{:code => params["code"]})
    IO.inspect token
    images = Instagram.user_recent_media(token.access_token)
    user = Repo.get(User, conn.private.plug_session["current_user"])
    users = Trophus.Repo.all(Trophus.User)
    changeset = User.changeset(user, %{"instagram_token" => token.access_token})

    if changeset.valid? do
      Repo.update(changeset)
      conn
      |> put_flash(:info, "Instagram token added to database")
      |> render "index.html", users: users
    else
      render(conn, "index.html", users: users)
    end
  end

  def instagram(conn, _params) do
    user = Trophus.Repo.get(User, conn.private.plug_session["current_user"])
    images = Instagram.user_recent_media(user.instagram_token)
    |> Enum.map fn(x) -> x["images"]["thumbnail"]["url"] end
    render(conn, "instagram.html", images: images)
  end

  def customer(conn, params) do

    # IO.inspect "Checking token"
    # IO.inspect params["token"]
    current_user_id = conn.private.plug_session["current_user"]
    tkn = params["token"]
    user = Repo.get!(User, current_user_id)
    username = user.name
    desc = username <> " customer token"
    HTTPotion.start
    content_type = "application/x-www-form-urlencoded"
    auth = "Bearer sk_test_aqQo51A1cGQEk09BCaCGmkYZ"
    stripe_customers_url = "https://api.stripe.com/v1/customers"
    headers = ["Content-type": content_type, "Authorization": auth]
    payload_content = "source="<>tkn<>"&description=" <> "\"#{desc}\""
    payload = [body: payload_content, headers: headers]

    response = HTTPotion.post stripe_customers_url, payload
    obj = Poison.decode! response.body
    customer_id = obj["id"]

    IO.puts customer_id
    response = HTTPotion.post "https://api.stripe.com/v1/accounts", [body: "country=US&managed=true", headers: ["Content-type": "application/x-www-form-urlencoded", "Authorization": "Bearer sk_test_aqQo51A1cGQEk09BCaCGmkYZ"]]
    bd = response.body
    dc = bd |> Poison.decode!
    pub = dc["keys"]["publishable"]     # publishable_key
    sct = dc["keys"]["secret"]          # secret_key
    act = dc["id"]                      # connect_id
    cset = %{customer_id: customer_id, publishable_key: pub, secret_key: sct, connect_id: act}
    IO.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    IO.puts "Watch the cset!"
    IO.inspect cset
    IO.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    changeset = User.changeset Repo.get!(User, current_user_id), cset
    if changeset.valid? do
      Repo.update(changeset)
    end
    conn
  end


  def add_ll(conn, params) do
    IO.inspect params
    user = Repo.get(User, conn.private.plug_session["current_user"])
    users = Trophus.Repo.all(Trophus.User)
    lat = String.to_float(params["latitude"])
    lng = String.to_float(params["longitude"])
    changeset = User.changeset(user, %{"latitude" => lat, "longitude" => lng})
    IO.inspect changeset
    if changeset.valid? do
      Repo.update(changeset)
      conn
      |> put_flash(:info, "User latitude/longitude added successfully.")
    end
    render(conn, "index.html", changeset: changeset, users: users)
  end

  def index(conn, _params) do
    users = Repo.all(User)
    IO.inspect conn.private.plug_session["current_user"]
    render(conn, "index.html", users: users)
  end

  def profile(conn, _params) do
    url = Instagram.start
    user = Repo.get(User, conn.private.plug_session["current_user"])
    IO.inspect "The current user is... "
    IO.inspect user
    {:ok, firstname} = String.split(user.name, " ") |> Enum.fetch 0
    {:ok, lastname} = String.split(user.name, " ") |> Enum.fetch 1

    render(conn, "profile.html", url: url, fname: firstname, lname: lastname, current_user: user)
  end

  def new(conn, _params) do
    changeset = User.changeset(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.changeset(%User{}, user_params)

    if changeset.valid? do
      Repo.insert(changeset)
      conn
      |> put_flash(:info, "User created successfully.")
      |> redirect(to: user_path(conn, :index))
    else
      render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Repo.get(User, id)
    render(conn, "show.html", user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = Repo.get(User, id)
    changeset = User.changeset(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Repo.get(User, id)
    changeset = User.changeset(user, user_params)

    if changeset.valid? do
      Repo.update(changeset)
      conn
      |> put_flash(:info, "User updated successfully.")
      |> redirect(to: user_path(conn, :index))
    else
      render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Repo.get(User, id)
    Repo.delete(user)
    conn
    |> put_flash(:info, "User deleted successfully.")
    |> redirect(to: user_path(conn, :index))
  end
end
