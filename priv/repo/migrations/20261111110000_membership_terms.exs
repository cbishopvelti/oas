defmodule Oas.Repo.Migrations.MembershipTerms do
  use Ecto.Migration

  # The agreement text that used to be hard-coded in the public membership
  # form (oas-web-public/src/Members/MembershipForm.js).
  @oxfordshire_terms """
  <h3>Agreement of Release and Waiver of Liability</h3>
  <p>
    The constitution: <a href="https://drive.google.com/file/d/1g2blgY6CL9IMuXT-8EJzvLMQTaiIGt2p/view">https://drive.google.com/file/d/1g2blgY6CL9IMuXT-8EJzvLMQTaiIGt2p/view?usp=sharing</a><br />
    <br/>
    By agreeing to the membership form<br/>
    - you recognize that insurance is in the responsibility of the participant and that you have an adequate accident insurance.<br/>
    - you agree that acrobatics require physical exertion that may be strenuous and may cause physical injury, and that you're fully aware of the risks and hazards involved.<br/>
    - you verify, and warrant that you're physically fit and that you have no medical condition that would prevent your full participation in this workshop.<br/>
    - you knowingly, voluntarily and expressly waive any claim you may have against by the organisers, for injury or damages that you may sustain as a result of participating in jams organised by the society.<br/>
  </p>
  """

  def up do
    alter table(:config_config) do
      add :membership_terms, :text, null: true
    end

    flush()

    # Keep the form unchanged for the existing society. A fresh install (no
    # members yet) starts with no terms, so a new society does not inherit
    # Oxfordshire's constitution link.
    repo().query!(
      "UPDATE config_config SET membership_terms = ?1 WHERE membership_terms IS NULL AND EXISTS (SELECT 1 FROM members)",
      [@oxfordshire_terms]
    )
  end

  def down do
    alter table(:config_config) do
      remove :membership_terms
    end
  end
end
