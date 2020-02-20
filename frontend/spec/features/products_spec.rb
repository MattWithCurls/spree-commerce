require 'spec_helper'

describe 'Visiting Products', type: :feature, inaccessible: true do
  include_context 'custom products'

  let(:store) { Spree::Store.default }

  let(:store_name) do
    ((first_store = Spree::Store.first) && first_store.name).to_s
  end

  before do
    visit spree.products_path
    allow(ENV).to receive(:[]).and_call_original
  end

  it 'is able to show the shopping cart after adding a product to it', js: true do
    click_link 'Ruby on Rails Ringer T-Shirt'
    expect(page).to have_content('$159.99')

    expect(page).to have_selector('form#add-to-cart-form')
    expect(page).to have_selector(:button, id: 'add-to-cart-button', disabled: false)
    click_button 'add-to-cart-button'
    expect(page).to have_content(Spree.t(:added_to_cart))
  end

  describe 'meta tags and title' do
    let(:jersey) { Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey') }
    let(:metas) { { meta_description: 'Brand new Ruby on Rails Jersey', meta_title: 'Ruby on Rails Baseball Jersey Buy High Quality Geek Apparel', meta_keywords: 'ror, jersey, ruby' } }

    it 'returns the correct title when displaying a single product' do
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey - ' + store_name)
      within('div#product-description') do
        within('h1.product-details-title') do
          expect(page).to have_content('Ruby on Rails Baseball Jersey')
        end
      end
    end

    it 'displays metas' do
      jersey.update metas
      click_link jersey.name
      expect(page).to have_meta(:description, 'Brand new Ruby on Rails Jersey')
      expect(page).to have_meta(:keywords, 'ror, jersey, ruby')
    end

    it 'displays title if set' do
      jersey.update metas
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey Buy High Quality Geek Apparel')
    end

    it "doesn't use meta_title as heading on page" do
      jersey.update metas
      click_link jersey.name
      within('h1') do
        expect(page).to have_content(jersey.name)
        expect(page).not_to have_content(jersey.meta_title)
      end
    end

    it 'uses product name in title when meta_title set to empty string' do
      jersey.update meta_title: ''
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey - ' + store_name)
    end
  end

  context 'using Russian Rubles as a currency' do
    before do
      store.update(default_currency: 'RUB')
    end

    let!(:product) do
      product = Spree::Product.find_by(name: 'Ruby on Rails Ringer T-Shirt')
      product.master.prices.create(amount: 19.99, currency: 'RUB')
      product.tap(&:save)
    end

    # Regression tests for #2737
    context 'uses руб as the currency symbol' do
      it 'on products page' do
        visit spree.products_path
        within("#product_#{product.id}") do
          within('.product-component-price') do
            expect(page).to have_content('19.99 ₽')
          end
        end
      end

      it 'on product page' do
        visit spree.product_path(product)
        within('.price') do
          expect(page).to have_content('19.99 ₽')
        end
      end

      it 'when adding a product to the cart', js: true do
        add_to_cart(product)

        within('.shopping-cart-total-amount') do
          expect(page).to have_content('19.99 ₽')
        end
      end

      it "when on the 'address' state of the cart", js: true do
        add_to_cart(product) do
          click_link 'Checkout'
        end

        within('#summary-order-total') do
          expect(page).to have_content('19.99 ₽')
        end
      end
    end
  end

  it 'is able to search for a product' do
    fill_in 'keywords', with: 'shirt'
    first('input[type=submit]').click

    expect(page).to have_css('.product-component-name').once
  end

  context 'a product with variants' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey') }
    let(:option_value) { create(:option_value) }
    let!(:variant) { build(:variant, price: 5.59, product: product, option_values: []) }

    before do
      image = File.open(File.expand_path('../fixtures/thinking-cat.jpg', __dir__))
      create_image(product, image)

      product.option_types << option_value.option_type
      variant.option_values << option_value
      variant.save!
    end

    it 'is displayed' do
      expect { click_link product.name }.not_to raise_error
    end

    it 'displays price of first variant listed', js: true do
      click_link product.name
      within('#product-price') do
        expect(page).to have_content variant.price
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display out of stock for master product" do
      product.master.stock_items.update_all count_on_hand: 0, backorderable: false

      click_link product.name
      within('#product-price') do
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display cart form if all variants (including master) are out of stock" do
      product.variants_including_master.each { |v| v.stock_items.update_all count_on_hand: 0, backorderable: false }

      click_link product.name
      within('[data-hook=product_price]') do
        expect(page).not_to have_content Spree.t(:add_to_cart)
      end
    end
  end

  context 'a product with variants, images only for the variants' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey') }
    let(:variant1) { create(:variant, product: product, price: 9.99) }
    let(:variant2) { create(:variant, product: product, price: 10.99) }

    before do
      image = File.open(File.expand_path('../fixtures/thinking-cat.jpg', __dir__))
      create_image(variant1, image)
    end

    it 'does not display no image available' do
      visit spree.products_path
      expect(page).to have_selector("img[data-src$='thinking-cat.jpg']")
    end
  end

  context 'an out of stock product without variants' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Tote') }

    before do
      product.master.stock_items.update_all count_on_hand: 0, backorderable: false
    end

    it 'does display out of stock for master product' do
      click_link product.name
      within('#inside-product-cart-form') do
        expect(page).to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display cart form if master is out of stock" do
      click_link product.name
      within('[data-hook=product_price]') do
        expect(page).not_to have_content Spree.t(:add_to_cart)
      end
    end
  end

  context 'product with taxons' do
    let(:product) { Spree::Product.find_by(name: 'Ruby on Rails Tote') }
    let(:taxon) { product.taxons.first }

    it 'displays breadcrumbs for the default taxon when none selected' do
      click_link product.name
      expect(page).to have_current_path(spree.product_path(product))
      within('#breadcrumbs') do
        expect(page).to have_content taxon.name
      end
    end

    it 'displays selected taxon in breadcrumbs' do
      taxon = Spree::Taxon.last
      product.taxons << taxon
      product.save!
      visit '/t/' + taxon.to_param
      click_link product.name
      expect(page).to have_current_path(spree.product_path(product, taxon_id: taxon.id))
      within('#breadcrumbs') do
        expect(page).to have_content taxon.name
      end
    end
  end

  it 'is able to hide products without price' do
    expect(page).to have_css('.product-component-name').exactly(9).times
    Spree::Config.show_products_without_price = false
    store.update(default_currency: 'CAD')
    visit spree.products_path
    expect(page).not_to have_css('.product-component-name')
  end

  it 'is able to display products priced under 50 dollars' do
    within(:css, '#collapseFilterPrice') { click_on 'Less than $50' }
    expect(page).to_not have_css('.product-component-name')
    expect(page).to have_content('No results')
  end

  it 'is able to display products priced between 50 and 100 dollars' do
    within(:css, '#collapseFilterPrice') { click_on '$50 - $100' }
    expect(page).to have_css('.product-component-name').exactly(2).times
    tmp = page.all('.product-component-name').map(&:text).flatten.compact
    tmp.delete('')
    expect(tmp.sort!).to eq(['Ruby on Rails Mug', 'Ruby on Rails Tote'])
  end

  it 'is able to display products priced between 101 and 150 dollars' do
    within(:css, '#collapseFilterPrice') { click_on '$101 - $150' }
    expect(page).to have_css('.product-component-name').once
    tmp = page.all('.product-component-name').map(&:text).flatten.compact
    tmp.delete('')
    expect(tmp.sort!).to eq(['Ruby on Rails Bag'])
  end

  it 'is able to display products priced between 151 and 200 dollars' do
    within(:css, '#collapseFilterPrice') { click_on '$151 - $200' }
    expect(page).to have_css('.product-component-name').exactly(4).times
    tmp = page.all('.product-component-name').map(&:text).flatten.compact
    tmp.delete('')
    expect(tmp.sort!).to eq(['Ruby on Rails Baseball Jersey',
                             'Ruby on Rails Jr. Spaghetti',
                             'Ruby on Rails Ringer T-Shirt',
                             'Ruby on Rails Stein'])
  end

  context 'pagination' do
    before { Spree::Config.products_per_page = 3 }

    it 'is able to display products priced between 151 and 200 dollars across multiple pages' do
      find(:css, '#filtersPrice').click
      within(:css, '#collapseFilterPrice') { click_on '$151 - $200' }
      expect(page).to have_css('.product-component-name').exactly(3).times
      next_page = find_all(:css, '.next_page')
      within(next_page[0]) { find(:css, '.page-link').click }
      expect(page).to have_css('.product-component-name').once
    end
  end

  it 'is able to put a product without a description in the cart', js: true do
    product = FactoryBot.create(:base_product, description: nil, name: 'Sample', price: '19.99')
    visit spree.product_path(product)
    expect(page).to have_selector('form#add-to-cart-form')
    expect(page).to have_button(id: 'add-to-cart-button', disabled: false)
    expect(page).to have_content 'This product has no description'
    click_button 'add-to-cart-button'
    expect(page).to have_content(Spree.t(:added_to_cart))
    expect(page).to have_content 'This product has no description'
  end

  it 'is not able to put a product without a current price in the cart' do
    product = FactoryBot.create(:base_product, description: nil, name: 'Sample', price: '19.99')
    store.update(default_currency: 'CAN')
    Spree::Config.show_products_without_price = true
    visit spree.product_path(product)
    expect(page).to have_content 'This product is not available in the selected currency.'
    expect(page).not_to have_content 'add-to-cart-button'
  end

  it 'returns the correct title when displaying a single product' do
    product = Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey')
    click_link product.name

    within('div#product-description') do
      within('h1.product-details-title') do
        expect(page).to have_content('Ruby on Rails Baseball Jersey')
      end
    end
  end

  context 'when rendering the product description' do
    context 'when <script> tag exists' do
      it 'prevents the script from running', js: true do
        description = '<script>window.alert("Message")</script>'
        product = FactoryBot.create(:base_product, description: description, name: 'Sample', price: '19.99')

        accept_alert(wait: 1) { visit spree.product_path(product) }
        fail 'XSS alert exists'

      rescue Capybara::ModalNotFound
      end

      it 'returns sanitized js text in html' do
        description = '<script>window.alert("Message")</script>'
        product = FactoryBot.create(:base_product, description: description, name: 'Sample', price: '19.99')
        visit spree.product_path(product)

        within('#product-description-long') do
          expect(text).to eq('window.alert("Message")')
        end
      end
    end

    context 'when <a> tag exists' do
      it 'returns <a> tag in html' do
        description = '<a href="example.com">link</a>'
        product = FactoryBot.create(:base_product, description: description, name: 'Sample', price: '19.99')
        visit spree.product_path(product)

        within('[data-hook=product_description]') do
          node = first('[data-hook=description]')
          expect(node).to have_selector 'a'
        end
      end
    end

    context 'when there are multiple lines' do
      it 'returns <p> tag in html' do
        description = "first paragraph\n\nsecond paragraph"
        product = FactoryBot.create(:base_product, description: description, name: 'Sample', price: '19.99')
        visit spree.product_path(product)

        within('[data-hook=product_description]') do
          node = first('[data-hook=description]')
          expect(node).to have_selector 'p'
        end
      end
    end
  end
end
