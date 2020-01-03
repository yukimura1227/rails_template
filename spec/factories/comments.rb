FactoryBot.define do
  factory :comment do
    content { "MyText" }
    blog { nil }
  end
end
