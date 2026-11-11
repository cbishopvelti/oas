defmodule Oas.Repo.Migrations.HomeIntroToContent do
  use Ecto.Migration

  # The public home page used to hard code Oxfordshire's heading and intro.
  # The heading now comes from the society name, and the intro moves into the
  # editable home page content (Settings > Content) so other societies can
  # write their own. Only installs that already have members get the text, so
  # a brand new society's database starts with empty content.

  @name "Oxfordshire Acro Society"

  @intro "<p>This is the virtual home of the Oxfordshire Acro Society.</p>" <>
           "<p>If you are joining for the first time, please go to “register” in the menu and sign up. " <>
           "You can come to 3 sessions as a temporary member before you must become a full member, " <>
           "full membership for this season runs until the 31st of October and is 12 GBP. " <>
           "Please register <a href=\"/register\">here</a></p>"

  def up do
    execute(fn ->
      if existing_install?() do
        repo().query!(
          "UPDATE config_config SET content = ? || COALESCE(content, '')",
          [@intro]
        )

        repo().query!(
          "UPDATE config_config SET name = ? WHERE name IS NULL OR TRIM(name) = ''",
          [@name]
        )
      end
    end)
  end

  def down do
    execute(fn ->
      repo().query!(
        "UPDATE config_config SET content = NULLIF(SUBSTR(content, ?), '') WHERE SUBSTR(content, 1, ?) = ?",
        [String.length(@intro) + 1, String.length(@intro), @intro]
      )
    end)
  end

  defp existing_install? do
    %{rows: [[count]]} = repo().query!("SELECT COUNT(*) FROM members")
    count > 0
  end
end
