require 'rails_helper'

feature 'timecop' do
  context 'Timecop#freeze sample' do
    before { Timecop.freeze(Time.now) }
    after { Timecop.return }
    let(:now) { Time.now }
    scenario 'Timecop#freeze stop the Time.now' do
      expect(Time.now).to eq now
    end
  end
  context 'Timecop#travel sample' do
    let(:travel_time) { Time.local(2035, 6, 10, 16, 22, 10) }
    before { Timecop.travel(travel_time) }
    after { Timecop.return }
    scenario 'time cop travel go to the target time' do
      expect(Time.now).to_not eq travel_time
      expect(Time.now > travel_time).to eq true
    end
  end
end
