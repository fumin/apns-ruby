module APNS

  class Element
    attr_accessor :index, :item
    def initialize(index:, item:)
      self.index = index
      self.item = item
    end
  end

  class InfiniteArray

    def initialize(buffer_size:)
      @buffer_size = buffer_size
      @buf = []
    end

    def push item
      @buf << Element.new(index: size, item: item)
      pop_front if @buf.size > @buffer_size
    end

    def size
      return 0 if @buf[0].nil?
      @buf.last.index + 1
    end

    def item_at index
      buf_index = buffer_index_from(index: index)
      return unless buf_index
      @buf[buf_index].item
    end

    def items_from index
      buf_index = buffer_index_from(index: index)
      return [] unless buf_index
      @buf[buf_index..-1].map(&:item)
    end

    def pop_front
      @buf = @buf[1..-1]
    end

    def delete_where_index_less_than index
      while @buf[0].index < index
        pop_front
      end
    end

    def clear
      @buf = []
      @hash = {}
    end

    def buffer_index_from(index:)
      return if index > @buf.last.index
      buf_index = index - @buf[0].index
      return if buf_index < 0
      buf_index
    end

  end

end
