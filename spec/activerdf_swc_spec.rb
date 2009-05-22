require 'spec/spec_helper'

describe SWCAdapter do
  SWCAdapter.class_eval { attr_reader :model }
  
  def mock_load(uri, syntax='rdfxml', filename=nil)
    if filename.nil?
      @adapter.expects(:load).once.with(uri, syntax)
    else  
      path = File.join(File.dirname(__FILE__), 'fixtures', "#{filename}.nt")
      @adapter.expects(:load).once.with(uri, syntax) do |u,s|
        parser = Redland::Parser.new('ntriples', "", nil)
        parser.parse_into_model(@adapter.model, "file:#{path}")
      end
    end
  end
  
  before(:each) do
    Namespace.register :doap, 'http://usefulinc.com/ns/doap#'
    Namespace.register :foaf, 'http://xmlns.com/foaf/0.1/'
    @tabulator = RDFS::Resource.new('http://dig.csail.mit.edu/2005/ajar/ajaw/data#Tabulator')
  end
  
  describe "splitting a query into triples" do
    before(:each) do
      ConnectionPool.clear
      @adapter = ConnectionPool.add_data_source(:type => :swc)
    end
    
    it do
      query = "SELECT ?a WHERE { <http://foo.com> <http://foo.com/bar> ?a . }"
      @adapter.send(:query_to_triples, query).should == [
        ['<http://foo.com>', '<http://foo.com/bar>', :a]
      ]
    end
    
    it do
      query = "SELECT ?a, ?n WHERE { <http://foo.com> <http://foo.com/bar> ?a . ?a <http://foo.com/name> ?n . }"
      @adapter.send(:query_to_triples, query).should == [
        ['<http://foo.com>', '<http://foo.com/bar>', :a],
        [:a, '<http://foo.com/name>', :n]
      ]
    end
    
  end
  
  describe "making unbound (?!) query statements optional" do
    before(:each) do
      ConnectionPool.clear
      @adapter = ConnectionPool.add_data_source(:type => :swc)
    end
    
    it do
      q1 = "SELECT ?a WHERE { <http://foo.com> <http://foo.com/bar> ?a . }"
      q2 = "SELECT DISTINCT ?a WHERE { <http://foo.com> <http://foo.com/bar> ?a . }"
      @adapter.send(:munge_query, q1).should == q2
    end
    
    it do
      q1 = "SELECT ?a, ?n WHERE { <http://foo.com> <http://foo.com/bar> ?a . ?a <http://foo.com/name> ?n . }"
      q2 = "SELECT DISTINCT ?a,?n WHERE { <http://foo.com> <http://foo.com/bar> ?a . OPTIONAL { ?a <http://foo.com/name> ?n .  }}"
      @adapter.send(:munge_query, q1).should == q2
    end
    
    it do
      q1 = "SELECT ?n WHERE { <http://foo.com> <http://foo.com/bar> ?a . ?a <http://foo.com/name> ?n . }"
      q2 = "SELECT DISTINCT ?a,?n WHERE { <http://foo.com> <http://foo.com/bar> ?a . OPTIONAL { ?a <http://foo.com/name> ?n .  }}"
      @adapter.send(:munge_query, q1).should == q2
    end
  end    
  
  describe "running a query for retriving the tabulator project's name" do
    before(:each) do
      ConnectionPool.clear
      @adapter = ConnectionPool.add_data_source(:type => :swc)
      
      mock_load('http://dig.csail.mit.edu/2005/ajar/ajaw/data', 'rdfxml', 'tabulator-clean')
      mock_load('http://usefulinc.com/ns/doap', 'rdfxml')
      
      @q = Query.new
      @q.select_distinct(:name)
      @q.where(@tabulator, DOAP::name, :name)
      
      @results = @q.execute
    end
    
    it "should have loaded some triples" do
      @adapter.should have_at_least(1).items
    end
    
    it "should have got some results" do
      @results.should == ['The Tabulator Project']
    end
  end
  
  describe "running a query for retriving each tabulator developer's name" do
    before(:each) do
      ConnectionPool.clear
      @adapter = ConnectionPool.add_data_source(:type => :swc)
      
      mock_load('http://dig.csail.mit.edu/2005/ajar/ajaw/data', 'rdfxml', 'tabulator-clean')
      mock_load('http://www.w3.org/People/Berners-Lee/card', 'rdfxml', 'timbl-clean')
      # mock_load('http://xmlns.com/foaf/0.1/name', 'rdfxml')
      mock_load('http://usefulinc.com/ns/doap', 'rdfxml')
      
      @q = Query.new
      @q.select_distinct(:name)
      @q.where(@tabulator, DOAP::developer, :dev)
      @q.where(:dev, FOAF::name, :name)
      
      @results = @q.execute
    end
    
    it "should have loaded some triples" do
      @adapter.should have_at_least(1).items
    end
    
    it "should have got some results" do
      @results.should == ['Timothy Berners-Lee']
    end
  end

  describe "running a query for retriving each tabulator developer friends' names" do
    before(:each) do
      ConnectionPool.clear
      @adapter = ConnectionPool.add_data_source(:type => :swc)
      
      mock_load('http://dig.csail.mit.edu/2005/ajar/ajaw/data', 'rdfxml', 'tabulator-clean')
      mock_load('http://www.w3.org/People/Berners-Lee/card', 'rdfxml', 'timbl-clean')
      mock_load('http://bblfish.net/people/henry/card', 'rdfxml', 'henry-clean')
      mock_load('http://usefulinc.com/ns/doap', 'rdfxml')
      # mock_load('http://xmlns.com/foaf/0.1/name')
      # mock_load('http://xmlns.com/foaf/0.1/knows')
      
      @q = Query.new
      @q.select_distinct(:name, :friends_name)
      @q.where(@tabulator, DOAP::developer, :dev)
      @q.where(:dev, FOAF::name, :name)
      @q.where(:dev, FOAF::knows, :friend)
      @q.where(:friend, FOAF::name, :friends_name)
      
      @results = @q.execute
    end
    
    it "should have loaded some triples" do
      @adapter.should have_at_least(1).items
    end
    
    it "should have got some results" do
      @results.should == [['Timothy Berners-Lee', 'Henry J. Story']]
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
