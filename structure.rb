require './encounter'
require './quest'
require './introduction'
require './chamber'
require './labyrinth'

CARDINAL_DIRECTIONS = ['N','S','E','W'].freeze

def move_position(position, direction)
  case direction
  when 'N' then [position.first, position.last-1]
  when 'NE' then [position.first+1, position.last-1]
  when 'E' then [position.first+1, position.last]
  when 'SE' then [position.first+1, position.last+1]
  when 'S' then [position.first, position.last+1]
  when 'SW' then [position.first-1, position.last+1]
  when 'W' then [position.first-1, position.last]
  when 'NW' then [position.first-1, position.last-1]
  end
end

def flip_direction(direction)
  case direction
  when 'N' then 'S'
  when 'S' then 'N'
  when 'E' then 'W'
  when 'W' then 'E'
  end
end

def cardinal_text(direction)
  case direction
  when 'N' then 'north'
  when 'E' then 'east'
  when 'S' then 'south'
  when 'W' then 'west'
  end
end

class Space
  attr_reader :position, :next_spaces

  def initialize(position, next_spaces)
    @position = position
    @next_spaces = next_spaces
  end
end

class Area
  attr_reader :grid

  def initialize(size=500)
    @size = size
    @spaces = {}
  end

  def get_placeholder_cells
    @spaces
  end

  def generate
    scatter_spaces
    translate_to_origin
    connect_grid
    link_pathways
    self
  end

  def to_labyrinth
    Labyrinth.new(@grid)
  end

  def connect_grid
    @grid.each do |row|
      row.each do |cell|
        if cell
          cell.north = grid_pointer(cell.position, 'N')
          cell.south = grid_pointer(cell.position, 'S')
          cell.west  = grid_pointer(cell.position, 'W')
          cell.east  = grid_pointer(cell.position, 'E')
        end
      end
    end
  end

  def grid_pointer(position, direction)
    x, y = move_position(position, direction)
    @grid[x][y] unless @grid[x].nil?
  end

  def link_pathways
    stack = []
    stack.push(start_chamber)

    while stack.any?
      current = stack.last
      neighbors = current.neighbors.select { |n| n.links.empty? }
      if neighbors.empty?
        stack.pop
      else
        neighbor = neighbors.sample
        current.link(neighbor)
        stack.push(neighbor)
      end
    end
  end

  def translate_to_origin
    width = max_x - min_x
    height = max_y - min_y
    origin = 0

    @grid = Array.new(width) { Array.new(height, false) }

    origin.upto(width-1) do |x|
      origin.upto(height-1) do |y|
        if @spaces.key?([x + min_x, y + min_y])
          @grid[x][y] = Chamber.new(x, y)
        else
          # @grid[x][y] = false
        end
      end
    end
  end

  def scatter_spaces
    add_space([0,0])
  end

  def start_chamber
    x,y = @spaces.keys.max_by { |(x, y)| x }
    @grid[x][y]
  end

  def max_x
    @max_x ||= @spaces.keys.max_by { |(x, y)| x }.first
  end

  def max_y
    @max_y ||= @spaces.keys.max_by { |(x, y)| y }.last
  end

  def min_x
    @min_x ||= @spaces.keys.min_by { |(x, y)| x }.first
  end

  def min_y
    @min_y ||= @spaces.keys.min_by { |(x, y)| y }.last
  end

  def move_next(position)
    next_spaces = CARDINAL_DIRECTIONS.reject do |direction|
      @spaces.key?(move_position(position, direction))
    end

    next_spaces.sample(rand(1..3))
  end

  def add_space(position)
    return if @spaces.count >= @size

    next_spaces = move_next(position)

    @spaces[position] = Space.new(position, next_spaces)

    next_spaces.each do |direction|
      add_space(move_position(position, direction))
    end
  end

  def dump_descriptions
    section = 0
    @grid.each_with_index do |row, x|
      row.each_with_index do |cell, y|
        if cell
          section += 1
          puts "§ #{section}"
          puts cell.generate_text
          puts cell.generate_exits
          puts
        end
      end
    end
  end

  def dump_map
    @grid.each do |row|
      buffer = String.new
      row.each do |cell|
        if cell
          buffer << '#'
        else
          buffer << ' '
        end
      end
      puts buffer
    end
  end
end

area = Area.new
area.generate
area.dump_descriptions

# p labyrinth[x, y]
#
# RecursiveBacktracker.on(labyrinth, labyrinth[x, y]).each_cell do |cell|
#   #p cell
# end

exit

chambers = area.get_placeholder_cells

map = []
wall = ' '.freeze
room = '#'.freeze
entrance = '@'.freeze
end_tile = '%'.freeze
found_start = false
found_end = false

min_x = area.min_x
min_y = area.min_y
max_x = area.max_x
max_y = area.max_y

if (max_x - min_x) > (max_y - min_y)
  check_start = -> (x,y) { x == min_x }
  check_end = -> (x,y) { x == max_x }
else
  check_start = -> (x,y) { y == min_y }
  check_end = -> (x,y) { y == max_y }
end

min_x.upto(max_x) do |x|
  row = []
  min_y.upto(max_y) do |y|
    chamber = chambers[[x,y]]
    if chamber.nil?
      row << {tile: wall, chamber: chamber}
    elsif chamber.position == '[0,0]'
      row << {tile: entrance, chamber: chamber}
    elsif !found_start && check_start.call(x,y)
      row << {tile: entrance, chamber: chamber}
      found_start = true
    elsif !found_end && check_end.call(x,y)
      row << {tile: end_tile, chamber: chamber}
      found_end = true
    else
      row << {tile: room, chamber: chamber}
    end
  end
  map << row
end

require 'rasem'

File.open("map.svg", "w") do |f|
  Rasem::SVGImage.new(800, 800, f) do |f|
    map.each_with_index do |row, i|
      row.each_with_index do |col, j|
        if col[:tile] == room
          exits = col[:chamber].next_spaces
          rectangle(i*10, j*10, 10, 10, :stroke_width=>1, :fill=> 'green')
          # line(i*10, j*10, i*10+10, j*10) unless exits.include?('N')
          # line(i*10, j*10, i*10, j*10+10) unless exits.include?('W')
          # line(i*10+10, j*10, i*10+10, j*10+10) unless exits.include?('E')
          # line(i*10, j*10+10, i*10+10, j*10+10) unless exits.include?('S')
        elsif col[:tile] == entrance
          exits = col[:chamber].next_spaces
          rectangle(i*10, j*10, 10, 10, :stroke_width=>1, :fill=> 'cyan')
          # line(i*10, j*10, i*10+10, j*10) unless exits.include?('N')
          # line(i*10, j*10, i*10, j*10+10) unless exits.include?('W')
          # line(i*10+10, j*10, i*10+10, j*10+10) unless exits.include?('E')
          # line(i*10, j*10+10, i*10+10, j*10+10) unless exits.include?('S')
        elsif col[:tile] == end_tile
          exits = col[:chamber].next_spaces
          rectangle(i*10, j*10, 10, 10, :stroke_width=>1, :fill=> 'orange')
          # line(i*10, j*10, i*10+10, j*10) unless exits.include?('N')
          # line(i*10, j*10, i*10, j*10+10) unless exits.include?('W')
          # line(i*10+10, j*10, i*10+10, j*10+10) unless exits.include?('E')
          # line(i*10, j*10+10, i*10+10, j*10+10) unless exits.include?('S')
        end
      end
    end
  end
end

# intro = Introduction.new
#
# File.open("map.html", "w") do |f|
#   f.puts '<meta charset="utf-8">'
#   f.puts '<body>'
#   f.puts '<img src="map.svg">'
#
#   f.puts '<h3>Introduction</h3>'
#   f.puts "<p>#{intro.generate}</p>"
#
#   chambers.each_with_index do |(position, chamber), i|
#     f.puts "<h3>§ #{i+1}</h3>"
#     f.puts "<p>#{chamber.generate_text}</p>"
#     f.puts "<p>#{chamber.generate_exits}</p>"
#   end
#   f.puts '</body>'
# end
