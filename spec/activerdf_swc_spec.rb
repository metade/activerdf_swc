require 'lib/activerdf_swc'

describe SWCAdapter do
  before(:each) do
    @adapter = ConnectionPool.add_data_source(:type => :swc, :location => 'swc.sqlite3')
  end
  
  it "should create a new reddy adapter" do
    @adapter.should_not be_nil
  end
  
  describe 'running a query' do
    before(:each) do
      # Namespace.register :foaf, 'http://xmlns.com/foaf/0.1/'
      # Namespace.register :doap, 'http://usefulinc.com/ns/doap#'
      # ObjectManager.construct_classes

      # SELECT DISTINCT ?name ?mbox ?projectName
      # WHERE { 
      #   <http://dig.csail.mit.edu/2005/ajar/ajaw/data#Tabulator> doap:developer ?dev .
      #   ?dev foaf:name ?name .
      #   OPTIONAL { ?dev foaf:mbox ?mbox }
      #   OPTIONAL { ?dev doap:project ?proj . 
      #              ?proj foaf:name ?projectName }
      # }
      
      @triples = @adapter.size
      
      @q = Query.new
      @q.select(:name)
      @q.where(RDFS::Resource.new('http://dig.csail.mit.edu/2005/ajar/ajaw/data#Tabulator'), RDFS::Resource.new('http://usefulinc.com/ns/doap#developer'), :dev)
      @q.where(:dev, RDFS::Resource.new('http://xmlns.com/foaf/0.1/name'), :name)
      
      @results = @q.execute
    end
    
    it "should have got some results" do
      p @results
    end
  end
end
