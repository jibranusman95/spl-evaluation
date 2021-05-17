# Provides an abstraction for performing boolean operations on a numerical range.
# Used for calculating the interaction of free and busy time periods on a schedule.
#
# A Block is a VALUE OBJECT which has a starting value (called `top` or `start`)
# and an ending value (called `bottom` or `end`). These properties are numeric
# values which could represent points in time, or an arbitrary numeric scale.
#
# Blocks can be combined and subtracted from one another to yield other blocks
# or arrays of blocks depending on whether the original blocks are contiguous or not.
#
# For example:
#   Addition of overlapping ranges:
#   Block.new(3, 8) + Block.new(5, 12) == Block.new(3, 12)
#
#   Subtraction of one block from the middle of another:
#   Block.new(5, 25) - Block.new(10, 20) == [Block.new(5, 10), Block.new(20, 25)]
#
class Block

  def initialize (from, to)
    if to < from
      @start, @end = to, from
    else
      @start, @end = from, to
    end
  end

  def inspect
    { :start => self.start, :end => self.end }.inspect
  end

  attr_reader :start, :end

  alias :top :start

  alias :bottom :end

  # ==========
  # = Length =
  # ==========

  def length
    bottom - top
  end

  # ==============
  # = Comparison =
  # ==============

  def == (other)
    if other.is_a? Array
      other.each do |time_block|
        return false if top != time_block.start && bottom != time_block.end
      end

      return true
    elsif other.is_a? Block
      top == other.start && bottom == other.end
    end
  end

  def <=> (other)
    [top, bottom] <=> [other.top, other.bottom]
  end

  def include? (n)
    top <= n && bottom >= n
  end

  # ============
  # = Position =
  # ============

  # This block entirely surrounds the other block.

  def surrounds? (other)
    other.top > top && other.bottom < bottom
  end

  def covers? (other)
    other.top >= top && other.bottom <= bottom
  end

  # This block intersects with the top of the other block.

  def intersects_top? (other)
    top <= other.top && other.include?(bottom)
  end

  # This block intersects with the bottom of the other block.

  def intersects_bottom? (other)
    bottom >= other.bottom && other.include?(top)
  end

  # This block overlaps with any part of the other block.

  def overlaps? (other)
    include?(other.top) || other.include?(top)
  end

  def no_overlap? (other)
    top >= other.end || bottom <= other.start
  end

  # ==============
  # = Operations =
  # ==============

  # A block encompassing both this block and the other.

  def union (other)
    Block.new([top, other.top].min, [bottom, other.bottom].max)
  end

  # A two element array of blocks created by cutting the other block out of this one.

  def split (other)
    [Block.new(top, other.top), Block.new(other.bottom, bottom)]
  end

  # A block created by cutting the top off this block.

  def trim_from (new_top)
    Block.new(new_top, bottom)
  end

  # A block created by cutting the bottom off this block.

  def trim_to (new_bottom)
    Block.new(top, new_bottom)
  end

  def limited (limiter)
    Block.new([top, limiter.top].max, [bottom, limiter.bottom].min)
  end

  def padded (top_padding, bottom_padding)
    Block.new(top - [top_padding, 0].max, bottom + [bottom_padding, 0].max)
  end

  # =============
  # = Operators =
  # =============
  
  # Return the result of adding the other Block (or Blocks) to self.

  def add (other)
    if other.is_a? Array
      [Block.new([top, arr_min].min, [bottom, arr_max].max)]
    elsif other.is_a? Block
      if overlaps? other
        [Block.new([top, other.start].min, [bottom, other.end].max)]
      else
        [other, self]
      end
    end
  end
  
  # Return the result of subtracting the other Block (or Blocks) from self.

  def subtract (other)
    if other.is_a? Block
      return [] if self == other
      return [self] if no_overlap?(other)

      if covers?(other)
        if intersects_bottom?(other)
          return [Block.new(other.end, bottom)]
        elsif intersects_top?(other)
          return [Block.new(top, other.start)]
        end
      end

      return [] if other.surrounds?(self) || intersects_bottom?(other) || other.intersects_bottom?(self)
      [Block.new([top, other.start].min, [top, other.start].max), Block.new([bottom, other.end].min, [bottom, other.end].max)]
    elsif other.is_a? Array
      new_arr = []

      (0...(other.length - 1)).each do |range_index|
        if other[range_index].no_overlap?(other[range_index + 1]) && overlaps?(other[range_index]) && overlaps?(other[range_index + 1])
          new_arr += [Block.new(other[range_index].end, other[range_index + 1].start)]
        end
      end

      new_arr
    end
  end

  alias :- :subtract

  alias :+ :add

  # An array of blocks created by adding each block to the others.

  def self.merge (blocks)
    blocks.sort_by(&:top).inject([]) do |blocks, b|
      if blocks.length > 0 && blocks.last.overlaps?(b)
        blocks[0...-1] + (blocks.last + b)
      else
        blocks + [b]
      end
    end
  end

  def merge (others)
    Block.merge([self, *others])
  end
end
