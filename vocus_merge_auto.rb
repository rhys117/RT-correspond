require_relative "rt_core"

class VocusMerge

  def initialize
    @tickets = new_vocus_responses
    response = RT.merge( :id      => 3,
                         :into_id => 5 )
    puts response
  end

  private
    def new_vocus_responses
      query = "Queue = 'Support' AND Owner = 'Nobody' AND "\
              "(  Status = 'open' OR Status = 'new' ) "\
              "AND Subject LIKE '[skymesh-support']"

      RT.list( :query => query )
    end
end

delete_cookies