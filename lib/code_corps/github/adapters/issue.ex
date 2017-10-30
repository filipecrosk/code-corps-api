defmodule CodeCorps.GitHub.Adapters.Issue do
  @moduledoc """
  Used to adapt a GitHub Issue payload into attributes for creating or updating
  a `CodeCorps.GithubIssue` and vice-versa.
  """

  alias CodeCorps.{
    Adapter.MapTransformer,
    GitHub.Adapters.Utils.BodyDecorator,
    GithubIssue,
    Task
  }

  @issue_mapping [
    {:body, ["body"]},
    {:closed_at, ["closed_at"]},
    {:comments_url, ["comments_url"]},
    {:events_url, ["events_url"]},
    {:github_created_at, ["created_at"]},
    {:github_id, ["id"]},
    {:github_updated_at, ["updated_at"]},
    {:html_url, ["html_url"]},
    {:labels_url, ["labels_url"]},
    {:locked, ["locked"]},
    {:number, ["number"]},
    {:state, ["state"]},
    {:title, ["title"]},
    {:url, ["url"]}
  ]

  @doc ~S"""
  Converts a GitHub Issue payload into a set of attributes used to create or
  update a `GithubIssue` record.
  """
  @spec to_issue(map) :: map
  def to_issue(%{} = payload) do
    payload |> MapTransformer.transform(@issue_mapping)
  end

  @task_mapping [
    {:created_at, ["created_at"]},
    {:markdown, ["body"]},
    {:modified_at, ["updated_at"]},
    {:status, ["state"]},
    {:title, ["title"]}
  ]

  @doc ~S"""
  Converts a GitHub Issue payload into a set of attributes used to create or
  update a `Task` record.
  """
  @spec to_task(map) :: map
  def to_task(%{} = payload) do
    payload |> MapTransformer.transform(@task_mapping)
  end

  @doc ~S"""
  Converts a `GithubIssue` record into attributes with the same keys as the
  GitHub API's Issue
  """
  @spec to_issue_attrs(GithubIssue.t) :: map
  def to_issue_attrs(%GithubIssue{} = github_issue) do
    github_issue
    |> Map.from_struct
    |> MapTransformer.transform_inverse(@issue_mapping)
  end

  @autogenerated_github_keys ~w(closed_at comments_url created_at events_url html_url id labels_url number updated_at url)

  @doc ~S"""
  Converts a `GithubIssue` or `Task` into a set of attributes used to create or
  update an associated GitHub Issue on the GitHub API.
  """
  @spec to_api(GithubIssue.t | Task.t) :: map
  def to_api(%GithubIssue{} = github_issue) do
    github_issue
    |> Map.from_struct
    |> MapTransformer.transform_inverse(@issue_mapping)
    |> Map.drop(@autogenerated_github_keys)
    |> BodyDecorator.add_code_corps_header(github_issue)
  end
  def to_api(%Task{} = task) do
    task
    |> Map.from_struct
    |> MapTransformer.transform_inverse(@task_mapping)
    |> Map.drop(@autogenerated_github_keys)
    |> BodyDecorator.add_code_corps_header(task)
  end
end
