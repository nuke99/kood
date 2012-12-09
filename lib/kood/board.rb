module Kood
  class Board
    include Toy::Store

    # Associations
    list :lists, List

    # Attributes
    attribute :custom_repo, String, virtual: true

    # Observers
    before_create :id_is_unique?
    before_create do |board|
      if custom_repo # Support external branches
        Kood.config.custom_repos[board.id] = custom_repo
        Kood.config.save!
      end
      Board.adapter! board.id # To create a board we need to change the checked out branch
    end

    def self.get(id)
      adapter! id
      super
    end

    def self.get!(id)
      super rescue raise "The specified board does not exist."
    end

    def self.current
      get Kood.config.current_board_id
    end

    def self.current!
      current or raise "No board has been checked out yet."
    end

    def is_current?
      Board.current.eql? self
    end

    def delete
      if is_current?
        `cd #{ root } && git reset --hard && git checkout master -q`
        Kood.config.current_board_id = nil
        Kood.config.save! unless Kood.config.changes.empty?
      end
      `cd #{ root } && git branch -D #{ id }`
      # Since we deleted the branch, the default behavior is not necessary
    end

    def checkout(options = {})
      Kood.config.current_board_id = id
      Kood.config.save! unless Kood.config.changes.empty?
      `cd #{ root } && git checkout #{ id } -q ` if options[:permanent]
    end

    def self.adapter!(board_id)
      board_root = root(board_id)
      adapter :git, Kood.repo(board_root), branch: board_id
      List.adapter! board_id, board_root
    end

    def root
      Board.root(id)
    end

    private

    def self.root(board_id)
      Kood.config.custom_repos[board_id] or Kood.root
    end

    def id_is_unique?
      raise "A board with this ID already exists." unless Board.get(id).nil?
    end
  end
end