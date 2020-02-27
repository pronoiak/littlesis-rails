describe OligrapherController, type: :controller do
  it do
    is_expected.to route(:get, '/oligrapher/find_nodes').to(action: :find_nodes)
  end

  it do
    is_expected.to route(:get, '/oligrapher/example').to(action: :example)
  end

  it do
    is_expected.to route(:post, '/oligrapher').to(action: :create)
  end

  it do
    is_expected.to route(:patch, '/oligrapher/789').to(action: :update, id: '789')
  end
end
