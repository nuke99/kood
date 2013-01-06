require 'toystore'

module Kood
  extend self

  # Path to where data, such as user configurations and boards, is stored
  KOOD_PATH = ".kood"
  KOOD_ROOT = Pathname(File.expand_path("~")).join(KOOD_PATH)

  def test?
    ENV['RACK_ENV'] == 'test'
  end

  # Default path to the repository where boards are stored
  def root
    @root ||= test? ? KOOD_ROOT.join('storage-test').to_s : KOOD_ROOT.join('storage').to_s
  end

  # File where configurations are stored
  def config_path
    test? ? "config-test.yml" : "config.yml"
  end

  # Init a repo (and create master branch since some git commands rely on its existence)
  def repo(path = root)
    @repo ||= {}
    @repo[path] ||= begin
      new_repo = Grit::Repo.init(path)
      Dir.chdir(path) # TODO This is not ideal but otherwise it would be necessary to pass
      # a :chdir option in all calls to Grit. This may be a bug in Grit related with the
      # --work-tree flag

      unless new_repo.branches.any? { |b| b.name == 'master' } # Check if master exists
        index = new_repo.index
        index.add('k', '')
        index.commit("init")
      end
      new_repo # If this has been done before, the above command will do nothing
    end
  end

  # Live configurations that need to be saved
  class Config
    include Toy::Store

    adapter :user_config, {}

    # Associations
    list :boards, Kood::Board

    # Attributes
    attribute :custom_repos,     Hash   # Support storing boards in external repos
    attribute :current_board_id, String # Can be stored externally, so checkout isn't enough

    # Only one instance of Config should be created
    def self.instance
      @@instance ||= get_or_create('config')
    end

    def select_board(board_id)
      self.current_board_id = board_id
      save! if changed?
    end

    def unselect_board
      select_board nil
    end
  end

  def config
    Config.instance # The singleton instance to be used outside this module
  end
end
