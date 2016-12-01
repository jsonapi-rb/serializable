require 'spec_helper'

describe JSONAPI::Serializable::Resource, '.attribute' do
  let(:klass) do
    Class.new(JSONAPI::Serializable::Resource) do
      type 'foo'
    end
  end

  let(:object)   { User.new }
  let(:resource) { klass.new(object: object) }

  subject { resource.as_jsonapi[:attributes] }

  context 'when supplied a block value' do
    before do
      klass.class_eval do
        attribute(:name) { 'foo' }
      end
    end

    it { is_expected.to eq(name: 'foo') }
  end

  context 'when defining multiple attributes' do
    before do
      klass.class_eval do
        attribute(:name)    { 'foo' }
        attribute(:address) { 'bar' }
      end
    end

    it { is_expected.to eq(name: 'foo', address: 'bar') }
  end

  context 'when no block supplied' do
    before do
      klass.class_eval do
        attribute :name
      end
      object.name = 'foo'
    end

    it 'forwards to @object' do
      expect(subject).to eq(name: 'foo')
    end
  end

  context 'when the attribute is conditional' do
    let(:resource) do
      klass.new(object: object, conditional: conditional)
    end

    before do
      require 'jsonapi/serializable/resource/conditional_fields'

      klass.class_eval do
        prepend JSONAPI::Serializable::Resource::ConditionalFields
      end
    end

    context 'via :if' do
      before do
        klass.class_eval do
          attribute :name, if: proc { @conditional } do
            'foo'
          end
        end
      end

      context 'and the clause is true' do
        let(:conditional) { true }

        it { is_expected.to eq(name: 'foo') }
      end

      context 'and the clause is false' do
        let(:conditional) { false }

        it { is_expected.to be_nil }
      end
    end

    context 'via :unless' do
      before do
        klass.class_eval do
          attribute :name, unless: proc { @conditional } do
            'foo'
          end
        end
      end

      context 'and the clause is true' do
        let(:conditional) { true }

        it { is_expected.to be_nil }
      end

      context 'and the clause is false' do
        let(:conditional) { false }

        it { is_expected.to eq(name: 'foo') }
      end
    end
  end

  it 'handles key transformations' do
    require 'jsonapi/serializable/resource/key_transform'

    klass = Class.new(JSONAPI::Serializable::Resource) do
      prepend JSONAPI::Serializable::Resource::KeyTransform
      self.key_transform = proc { |k| k.to_s.capitalize }
      type 'foo'
      attribute :name do
        'bar'
      end
      attribute :address do
        'foo'
      end
    end
    resource = klass.new(object: User.new)
    actual = resource.as_jsonapi[:attributes]
    expected = {
      Name: 'bar',
      Address: 'foo'
    }

    expect(actual).to eq(expected)
  end
end
