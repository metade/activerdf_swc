require 'spec/spec_helper'

describe SWCAdapter do
  
  def mock_fetch(uri, filename=nil)
    triples = ''
    unless (filename.nil?)
      path = File.join(File.dirname(__FILE__), 'fixtures', "#{filename}.nt")
      File.open(path) { |f| triples = f.read }
    end
    @adapter.expects(:`).with(%[rapper --scan --quiet "#{uri}"]).returns(triples)
  end
  
  before(:each) do
    Namespace.register :doap, 'http://usefulinc.com/ns/doap#'
    @tabulator = RDFS::Resource.new('http://dig.csail.mit.edu/2005/ajar/ajaw/data#Tabulator')
  end
  
  describe 'running a simple query' do
    before(:each) do
      ConnectionPool.clear
      @adapter = ConnectionPool.add_data_source(:type => :swc)
      
      mock_fetch('http://dig.csail.mit.edu/2005/ajar/ajaw/data', 'tabulator-clean')
      mock_fetch('http://usefulinc.com/ns/doap', 'doap-clean')
      
      @q = Query.new
      @q.select_distinct(:name)
      @q.where(@tabulator, DOAP::name, :name)
      
      @results = @q.execute
    end
    
    it "should have loaded some triples" do
      @adapter.size.should == 11
    end
    
    it "should have got some results" do
      @results.should == ['The Tabulator Project']
    end    
  end 
  
  # describe 'running a query' do
  #   before(:each) do
  #     # SELECT DISTINCT ?name ?mbox ?projectName
  #     # WHERE { 
  #     #   <http://dig.csail.mit.edu/2005/ajar/ajaw/data#Tabulator> doap:developer ?dev .
  #     #   ?dev foaf:name ?name .
  #     #   OPTIONAL { ?dev foaf:mbox ?mbox }
  #     #   OPTIONAL { ?dev doap:project ?proj . 
  #     #              ?proj foaf:name ?projectName }
  #     # }
  #     
  #     @triples = @adapter.size
  #     
  #     @q = Query.new
  #     @q.select_distinct(:name) #, :mbox)
  #     @q.where(RDFS::Resource.new('http://dig.csail.mit.edu/2005/ajar/ajaw/data#Tabulator'), RDFS::Resource.new('http://usefulinc.com/ns/doap#developer'), :dev)
  #     @q.where(:dev, RDFS::Resource.new('http://xmlns.com/foaf/0.1/name'), :name)
  #     # @q.where(:dev, RDFS::Resource.new('http://xmlns.com/foaf/0.1/mbox'), :mbox)
  #     
  #     @results = @q.execute
  #   end
  #   
  #   it "should have got some results" do
  #     p @results
  #   end
  # end 
  
  # describe 'running another query' do
  #   before(:each) do
  #     # PREFIX foaf: <http://xmlns.com/foaf/0.1/ >
  #     # 
  #     # SELECT DISTINCT ?friendsname ?friendshomepage ?foafsname ?foafshomepage  
  #     # WHERE {
  #     #   { < http://richard.cyganiak.de/foaf.rdf#cygri > foaf:knows ?friend .
  #     #     ?friend foaf:mbox_sha1sum ?mbox . 
  #     #     ?friendsURI foaf:mbox_sha1sum ?mbox .
  #     #     ?friendsURI foaf:name ?friendsname .
  #     #     ?friendsURI foaf:homepage ?friendshomepage . }
  #     #     OPTIONAL { ?friendsURI foaf:knows ?foaf .
  #     #                ?foaf foaf:name ?foafsname .
  #     #                ?foaf foaf:homepage ?foafshomepage .
  #     #              } 
  #     #   }      
  #     @triples = @adapter.size
  #     
  #     @q = Query.new
  #     @q.select_distinct(:friendsname, :friendshomepage)
  #     @q.where(RDFS::Resource.new('http://richard.cyganiak.de/foaf.rdf#cygri'), RDFS::Resource.new('http://xmlns.com/foaf/0.1/knows'), :friend)
  #     @q.where(:friend, RDFS::Resource.new('http://xmlns.com/foaf/0.1/mbox_sha1sum'), :mbox)
  #     @q.where(:friendsURI, RDFS::Resource.new('http://xmlns.com/foaf/0.1/mbox_sha1sum'), :mbox)
  #     @q.where(:friendsURI, RDFS::Resource.new('http://xmlns.com/foaf/0.1/mbox_sha1sum'), :friendsname)
  #     @q.where(:friendsURI, RDFS::Resource.new('http://xmlns.com/foaf/0.1/homepage'), :friendshomepage)
  #     @results = @q.execute
  #   end
  #   
  #   it "should have got some results" do
  #     p @results
  #   end
  # end 
end
