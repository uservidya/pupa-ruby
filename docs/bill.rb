# The [cat.rb](http://opennorth.github.io/pupa-ruby/docs/cat.html) example goes
# over the basics of using Pupa.rb. This covers some more advanced topics.
require 'pupa'

# Defines a new class to model legislative bills. In this example, we will
# simply extract the names of bills and associate each bill with a sponsor and a
# legislative body.
class Bill < Pupa::Base
  self.schema = '/path/to/json-schema/bill.json'

  attr_accessor :name, :sponsor_id, :organization_id, :sponsor, :organization

  # When saving extracted objects to a database, these foreign keys will be used
  # to derive an evaluation order.
  foreign_key :sponsor_id, :organization_id

  # Sometimes, you may not know the ID of an existing foreign object, but you
  # may have other information to identify it. In that case, put the information
  # you have in a property named after the foreign key without the `_id` suffix:
  # for example, `sponsor` for `sponsor_id`. Before saving the object to the
  # database, Pupa.rb will use this information to identify the foreign object.
  foreign_object :sponsor, :organization

  # Overrides the `sponsor=` setter to automatically add the `_type` property,
  # instead of having to add it each time in the processor.
  def sponsor=(sponsor)
    @sponsor = {'_type' => 'pupa/person'}.merge(sponsor)
  end

  def organization=(organization)
    @organization = {'_type' => 'pupa/organization'}.merge(organization)
  end

  def to_s
    name
  end
end

# Scrapes legislative information about the Parliament of Canada.
class ParliamentOfCanada < Pupa::Processor
  # Instead of defining a single `extract` method to perform all the extraction,
  # we define an extraction task for each type of data we want to extract:
  # people, organizations and bills.
  #
  # This will let us later, for example, run each task on a different schedule.
  # Bill data is updated more frequently than person data; we would therefore
  # run the bills task more frequently.
  #
  # See the [`extract_task_method`](https://github.com/opennorth/pupa-ruby/blob/master/lib/pupa/processor.rb#L158)
  # documentation for more information on the naming of extraction methods.
  def extract_people
    doc = get('http://www.parl.gc.ca/MembersOfParliament/MainMPsCompleteList.aspx?TimePeriod=Current&Language=E')
    doc.css('#MasterPage_MasterPage_BodyContent_PageContent_Content_ListContent_ListContent_grdCompleteList tr:gt(1)').each do |row|
      person = Pupa::Person.new
      person.name = row.at_css('td:eq(1)').text.match(/\A([^,]+?), ([^(]+?)(?: \(.+\))?\z/)[1..2].
        reverse.map{|component| component.strip.squeeze(' ')}
      Fiber.yield(person)
    end
  end

  # Hardcodes the top-level organizations within Parliament.
  def extract_organizations
    parliament = Pupa::Organization.new(name: 'Parliament of Canada')
    Fiber.yield(parliament)

    house_of_commons = Pupa::Organization.new(name: 'House of Commons', parent: parliament)
    Fiber.yield(house_of_commons)

    senate = Pupa::Organization.new(name: 'Senate', parent: parliament)
    Fiber.yield(senate)
  end

  def extract_bills
    doc = get('http://www.parl.gc.ca/LegisInfo/Home.aspx?language=E&ParliamentSession=41-1&Mode=1&download=xml')
    doc.xpath('//Bill').each do |row|
      bill = Bill.new
      bill.name = row.at_xpath('./BillTitle/Title[@language="en"]').text
      # Here, we tell the Bill everything we know about the sponsor and the
      # legislative body. Pupa.rb will later determine which objects match the
      # given information.
      bill.sponsor = {
        name: row.at_xpath('./SponsorAffiliation/Person/FullName').text,
      }
      bill.organization = {
        name: row.at_xpath('./BillNumber/@prefix').value == 'C' ? 'House of Commons' : 'Senate',
      }
      Fiber.yield(bill)
    end
  end
end

ParliamentOfCanada.add_extract_task(:bills)
ParliamentOfCanada.add_extract_task(:organizations)
ParliamentOfCanada.add_extract_task(:people)

# By default, if you run `bill.rb`, it will perform all extraction tasks and
# load all the extracted objects into the database. Use the `--action` and
# `--task` switches to control the processors behavior.
Pupa::Runner.new(ParliamentOfCanada).run(ARGV)