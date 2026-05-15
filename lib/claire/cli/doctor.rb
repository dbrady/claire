# frozen_string_literal: true

require "claire/cli/init"

module Claire
  module CLI
    # Doctor is the heal-and-bootstrap verb. It is intentionally a thin
    # subclass of Init (#38): both verbs are front doors to the same
    # idempotent heal action. The reason to have two verbs is mental model,
    # not behavior — `init` is what new users discover from setup docs;
    # `doctor` is what experienced users reach for during routine
    # maintenance. Diverge the implementations only when there is a
    # behavior difference worth the duplication; today there is none.
    class Doctor < Init
    end
  end
end
