defmodule MdeditWeb.Utils do
  @moduledoc """
  Utility functions for the web application.
  """

  @doc """
  A utility function for merging Tailwind CSS classes with conflict resolution.

  This is similar to the `cn` utility from shadcn/ui. It uses the `TwMerge` library
  to intelligently merge Tailwind classes and resolve conflicts.

  ## Examples

      iex> cn(["px-2 py-1", "px-4", nil, "bg-blue-500"])
      "py-1 px-4 bg-blue-500"

      iex> cn("text-sm", "text-lg font-bold", nil)
      "text-lg font-bold"

      iex> cn("mb-2", "mb-0")
      "mb-0"

      iex> cn([
      ...>   "w-full input",
      ...>   condition && "input-bordered",
      ...>   "mb-2"
      ...> ])
      "w-full input input-bordered mb-2"  # when condition is true
  """
  def cn(classes) when is_list(classes) do
    classes
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&(&1 == false))
    |> Enum.map(&to_string/1)
    |> Enum.join(" ")
    |> TwMerge.merge()
  end

  def cn(class) when is_binary(class) or is_nil(class) do
    cn([class])
  end

  def cn(class1, class2) do
    cn([class1, class2])
  end

  def cn(class1, class2, class3) do
    cn([class1, class2, class3])
  end

  def cn(class1, class2, class3, class4) do
    cn([class1, class2, class3, class4])
  end

  # Handle more arguments using varargs
  def cn(class1, class2, class3, class4, class5) do
    cn([class1, class2, class3, class4, class5])
  end
end
