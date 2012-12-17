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
      Board.adapter! board.id # To create a board we need to change the current branch
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
      current or raise "No board has been selected yet."
    end

    def is_current?
      Board.current.eql? self
    end

    def delete
      if is_current?
        adapter.client.git.reset(hard: true)
        adapter.client.git.checkout({}, 'master')
        Kood.config.current_board_id = nil
        Kood.config.save! unless Kood.config.changes.empty?
      end
      adapter.client.git.branch({ :D => true }, id)
      # Since we deleted the branch, the default behavior is not necessary
    end

    def cards
      lists.inject([]) { |cards, list| cards += list.cards }
    end

    def select
      Kood.config.current_board_id = id
      Kood.config.save! unless Kood.config.changes.empty?
    end

    # git remote add upstream https://github.com/user/repo.git
    # puts adapter.client.remote_list
    def pull(remote = 'origin')
      adapter.client.with_stash do
        adapter.client.with_branch({}, id) do
          adapter.client.git.pull({ process_info: true }, remote, id)
        end
      end
    end

    def push(remote = 'origin')
      adapter.client.with_stash do
        adapter.client.with_branch({}, id) do
          adapter.client.git.push({ process_info: true }, remote, id)
        end
      end
    end

    def sync(remote = 'origin')
      exit_status, out, err = pull(remote)
      exit_status.zero? ? push(remote) : [exit_status, out, err]
    end

    def root
      Board.root(id)
    end

    def self.adapter!(board_id)
      board_root = root(board_id)
      adapter :git, Kood.repo(board_root), branch: board_id
      List.adapter! board_id, board_root
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
