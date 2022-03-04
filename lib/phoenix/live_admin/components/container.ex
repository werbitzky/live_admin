defmodule Phoenix.LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use Phoenix.HTML

  import Phoenix.LiveAdmin,
    only: [resource_title: 3, get_config: 3]

  alias __MODULE__.{Form, Index}
  alias Phoenix.LiveAdmin.{Resource, SessionStore}

  @impl true
  def mount(%{"resource_id" => key}, %{"id" => session_id}, socket) do
    {resource, config} = Map.fetch!(socket.assigns.resources, key)

    SessionStore.get_or_init(session_id)

    socket =
      assign(socket,
        resource: resource,
        key: key,
        config: config,
        session_id: session_id,
        loading: !connected?(socket)
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket = %{assigns: %{live_action: :edit, loading: false}}) do
    socket = assign_prefix(socket, params["prefix"])

    record =
      params
      |> Map.fetch!("record_id")
      |> Resource.find!(socket.assigns.resource, socket.assigns.prefix)

    socket = assign(socket, record: record)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _uri, socket = %{assigns: %{live_action: :list, loading: false}}) do
    page = String.to_integer(params["page"] || "1")

    sort = {
      String.to_existing_atom(params["sort-dir"] || "asc"),
      String.to_existing_atom(params["sort-attr"] || "id")
    }

    socket =
      socket
      |> assign(page: page)
      |> assign(sort: sort)
      |> assign(search: params["s"])
      |> assign_prefix(params["prefix"])

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_prefix", params, socket) do
    {
      :noreply,
      push_redirect(socket,
        to: route_with_params(socket, [:list, socket.assigns.key], prefix: params["prefix"])
      )
    }
  end

  def render(assigns = %{loading: true}), do: ~H""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__banner">
      <h1 class="resource__title">
        <%= resource_title(@resource, @config, @base_path) %>
      </h1>

      <div class="resource__actions">
        <div>
          <%= live_redirect "List", to: route_with_params(@socket, [:list, @key], prefix: @prefix), class: "resource__action--btn" %>
          <%= if get_config(@config, :create_with, true) do %>
            <%= live_redirect "New", to: route_with_params(@socket, [:new, @key]), class: "resource__action--btn" %>
          <% end %>
          <%= if Application.get_env(:phoenix_live_admin, :prefix_options) do %>
            <div class="resource__action--drop">
              <button><%= @prefix || "Set prefix" %></button>
              <nav>
                <ul>
                  <%= if @prefix do %>
                    <li>
                      <a href="#" phx-click="set_prefix">clear</a>
                    </li>
                  <% end %>
                  <%= for option <- get_prefix_options!(), to_string(option) != @prefix do %>
                    <li>
                      <a href="#" phx-click="set_prefix" phx-value-prefix={option}><%= option %></a>
                    </li>
                  <% end %>
                </ul>
              </nav>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <div class="flash">
      <p class="resource__error"><%= live_flash(@flash, :error) %></p>
      <p class="resource__info"><%= live_flash(@flash, :info) %></p>
    </div>

    <%= render "#{@live_action}.html", assigns %>
    """
  end

  def render("new.html", assigns) do
    changeset =
      assigns.resource
      |> struct()
      |> Ecto.Changeset.change()

    ~H"""
    <.live_component
      module={Form}
      id="create-form"
      resource={@resource}
      config={@config}
      changeset={changeset}
      action="create"
      session_id={@session_id}
      key={@key}
      resources={@resources}
    />
    """
  end

  def render("edit.html", assigns) do
    ~H"""
    <.live_component
      module={Form}
      id="edit-form"
      resource={@resource}
      config={@config}
      action="update"
      session_id={@session_id}
      key={@key}
      record={@record}
      resources={@resources}
    />
    """
  end

  def render("list.html", assigns) do
    ~H"""
    <.live_component
      module={Index}
      id="list"
      socket={@socket}
      resources={@resources}
      resource={@resource}
      config={@config}
      key={@key}
      page={@page}
      sort={@sort}
      search={@search}
      prefix={@prefix}
      session_id={@session_id}
    />
    """
  end

  def route_with_params(socket, segments, params \\ %{}) do
    params =
      Enum.flat_map(params, fn
        {:prefix, nil} -> []
        pair -> [pair]
      end)

    apply(socket.router.__helpers__(), :resource_path, [socket] ++ segments ++ [params])
  end

  def get_prefix_options!() do
    Application.fetch_env!(:phoenix_live_admin, :prefix_options)
    |> case do
      {mod, func, args} -> apply(mod, func, args)
      list when is_list(list) -> list
    end
    |> Enum.sort()
  end

  def assign_prefix(_, prefix \\ nil)

  def assign_prefix(socket, nil) do
    case SessionStore.lookup(socket.assigns.session_id, :__prefix__) do
      nil ->
        assign(socket, :prefix, nil)

      prefix ->
        IO.inspect(socket.assigns)
        socket
        |> assign(:prefix, prefix)
        |> push_redirect(
          to: route_with_params(socket, [:list, socket.assigns.key], prefix: prefix)
        )
    end
  end

  def assign_prefix(socket, prefix) do
    SessionStore.set(socket.assigns.session_id, :__prefix__, prefix)

    assign(socket, :prefix, prefix)
  end
end