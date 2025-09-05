# MDEdit

A collaborative markdown editor built with Phoenix LiveView. Edit documents together in real-time with a clean split-pane interface.

## What it does

- **Real-time collaboration** - Multiple people can edit the same document simultaneously
- **Live preview** - See your markdown rendered as you type
- **GitHub flavored markdown** - Tables, checkboxes, code blocks, and more
- **Clean interface** - Editor on the left, preview on the right
- **Automatic saving** - Your work is saved automatically

## Quick start

```bash
# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit `localhost:4000` and start writing!

## Usage

Create a new document by visiting `/editor` or clicking "New Document". Share the URL with others to collaborate. Everyone's changes appear instantly.

**Keyboard shortcuts:**
- `Ctrl/Cmd + S` - Save document
- `Tab` - Insert tab (instead of jumping to next field)

## How it works

Built with Phoenix LiveView for real-time updates, Phoenix PubSub for collaboration, and Earmark for markdown parsing. Uses PostgreSQL to store documents and Tailwind CSS with DaisyUI for styling.

## Development

Run tests and checks:
```bash
mix precommit
```

Start with interactive shell:
```bash
iex -S mix phx.server
```

## Contributing

Fork, create a branch, make changes, run `mix precommit`, and submit a PR.

## Learn more about Phoenix

* Website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Forum: https://elixirforum.com/c/phoenix-forum