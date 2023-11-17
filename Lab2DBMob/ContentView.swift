import SwiftUI
import SQLite
import Contacts
import MapKit

struct Book: Identifiable {
    var id: Int
    var name: String
    var authorName: String
    var yearOfPublish: Int
    var publisherAddress: String
    var numberOfPages: Int
}

struct ContentView: SwiftUI.View {
    private var dbPath = "/Users/sviatoslavromankiv/Documents/books.sqlite3"

    @State private var books: [Book] = []
    @State private var newBookName: String = ""
    @State private var newBookAuthorName: String = ""
    @State private var newBookYearOfPublish: String = ""
    @State private var newBookPublisherAddress: String = ""
    @State private var newBookNumberOfPages: String = ""

    @State private var isShowingOlderBooks = false

    @State private var contacts: [CNContact] = []

    @State private var selectedBookForMap: Book?

    var body: some SwiftUI.View {
        TabView {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("New Book")) {
                            HStack {
                                TextField("Name", text: $newBookName)
                                TextField("Author Name", text: $newBookAuthorName)
                            }
                            HStack {
                                TextField("Year of Publish", text: $newBookYearOfPublish)
                                    .keyboardType(.numberPad)
                                TextField("Number of Pages", text: $newBookNumberOfPages)
                                    .keyboardType(.numberPad)
                            }
                            TextField("Publisher Address", text: $newBookPublisherAddress)
                            Button("Add Book") {
                                addBook()
                                fetchBooks()
                            }
                        }
                        Section(header: Text("Filter")) {
                            Button("Show Books Older Than 10 Years") {
                                isShowingOlderBooks.toggle()
                            }
                            .sheet(isPresented: $isShowingOlderBooks) {
                                OlderBooksView(olderBooks: olderBooks, allBooksCount: books.count)
                            }
                        }
                    }

                    List {
                        ForEach(books) { book in
                            VStack(alignment: .leading) {
                                Text("Id: \(book.id)")
                                Text("Name: \(book.name)")
                                Text("Author: \(book.authorName)")
                                Text("Year of Publish: \(book.yearOfPublish)")
                                Text("Publisher Address: \(book.publisherAddress)")
                                Text("Number of Pages: \(book.numberOfPages)")
                            }
                            .onTapGesture {
                                selectedBookForMap = book
                            }
                            .foregroundStyle(book.id == selectedBookForMap?.id ? Color.blue : Color.black)

                            Button("Delete") {
                                deleteBook(id: book.id)
                                fetchBooks()
                            }
                        }
                    }
                    .onAppear {
                        fetchBooks()
                    }
                }
                .padding()
            }
            .tabItem {
                Label("Books", systemImage: "book")
            }

            NavigationView {
                MapView(selectedBook: $selectedBookForMap)
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }

            NavigationView {
                ContactsView(contacts: $contacts)
            }
            .tabItem {
                Label("Contacts", systemImage: "person.crop.circle")
            }
        }
    }

    var olderBooks: [Book] {
        let currentDate = Calendar.current.component(.year, from: Date())
        return books.filter { book in
            currentDate - book.yearOfPublish > 10
        }
    }

    func deleteBook(id: Int) {
        do {
            let database = try Connection(dbPath)

            let booksTable = Table("books")
            let bookId = Expression<Int>("id")

            let book = booksTable.filter(bookId == id)
            try database.run(book.delete())
        } catch {
            print(error.localizedDescription)
        }
    }

    func addBook() {
        guard let yearOfPublishInt = Int(newBookYearOfPublish),
              let numberOfPagesInt = Int(newBookNumberOfPages) else {
            return
        }

        do {
            let database = try Connection(dbPath)

            let booksTable = Table("books")
            let id = Expression<Int>("id")
            let name = Expression<String>("name")
            let authorName = Expression<String>("authorName")
            let yearOfPublish = Expression<Int>("yearOfPublish")
            let publisherAddress = Expression<String>("publisherAddress")
            let numberOfPages = Expression<Int>("numberOfPages")

            try database.run(booksTable.create(ifNotExists: true) { table in
                table.column(id, primaryKey: true)
                table.column(name)
                table.column(authorName)
                table.column(yearOfPublish)
                table.column(publisherAddress)
                table.column(numberOfPages)
            })

            let insert = booksTable.insert(
                name <- newBookName,
                authorName <- newBookAuthorName,
                yearOfPublish <- yearOfPublishInt,
                publisherAddress <- newBookPublisherAddress,
                numberOfPages <- numberOfPagesInt
            )
            try database.run(insert)
        } catch {
            print(error.localizedDescription)
        }
    }

    func fetchBooks() {
        do {
            let database = try Connection(dbPath)

            let booksTable = Table("books")
            let id = Expression<Int>("id")
            let name = Expression<String>("name")
            let authorName = Expression<String>("authorName")
            let yearOfPublish = Expression<Int>("yearOfPublish")
            let publisherAddress = Expression<String>("publisherAddress")
            let numberOfPages = Expression<Int>("numberOfPages")

            books = try database.prepare(booksTable).map { row in
                return Book(
                    id: row[id],
                    name: row[name],
                    authorName: row[authorName],
                    yearOfPublish: row[yearOfPublish],
                    publisherAddress: row[publisherAddress],
                    numberOfPages: row[numberOfPages]
                )
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct OlderBooksView: SwiftUI.View {
    var olderBooks: [Book]
    var allBooksCount: Int

    var body: some SwiftUI.View {
        NavigationView {
            List {
                Text("Percentage: \(String(format: "%.2f", Double(olderBooks.count) / Double(allBooksCount) * 100))%")
                ForEach(olderBooks) { book in
                    Text("Name: \(book.name)")
                }
            }
            .navigationTitle("Older than 10 Years")
        }
    }
}

struct ContactsView: SwiftUI.View {
    @SwiftUI.Binding var contacts: [CNContact]

    var body: some SwiftUI.View {
        List(contacts.filter { $0.familyName.hasSuffix("ко") }) { contact in
            VStack(alignment: .leading) {
                Text("Name: \(contact.givenName) \(contact.familyName)")
            }
        }
        .navigationTitle("Ending with 'ко'")
        .onAppear {
            fetchContacts()
        }
    }

    private func fetchContacts() {
        let store = CNContactStore()
        let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey]

        store.requestAccess(for: .contacts) { (granted, error) in
            if granted {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch as [CNKeyDescriptor])
                var fetchedContacts: [CNContact] = []

                DispatchQueue.global(qos: .background).async {
                    try? store.enumerateContacts(with: request) { contact, _ in
                        fetchedContacts.append(contact)
                    }

                    self.contacts = fetchedContacts
                }
            }
        }
    }
}

struct MapView: SwiftUI.View {
    @SwiftUI.Binding var selectedBook: Book?
    @State private var publisherCoordinate: CLLocationCoordinate2D?

    @State private var selectedResult: MKMapItem?
    @State private var route: MKRoute?

    @State private var position: MapCameraPosition = .automatic

    var body: some SwiftUI.View {
        VStack {
            if let publisherCoordinate {
                MapReader { reader in
                    Map(position: $position) {
                        Marker("Publisher", coordinate: publisherCoordinate)

                        if let route {
                            MapPolyline(route)
                                .stroke(.blue, lineWidth: 5)
                        }
                    }
                    .onChange(of: selectedResult){
                        getDirections()
                    }
                    .onTapGesture(perform: { screenCoord in
                        guard let pinLocation = reader.convert(screenCoord, from: .local) else { return }
                        print(pinLocation)
                        self.selectedResult = MKMapItem(placemark: MKPlacemark(coordinate: pinLocation))
                    })
                }
            }
            else
            {
                Text("Please select a book from the Books tab.")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Map")
        .onAppear{
            position = .automatic
            fetchPublisherCoordinates(book: selectedBook)
            getDirections()
        }
    }

    func getDirections() {
        route = nil

        guard let selectedResult else { return }
        guard let publisherCoordinate else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: publisherCoordinate))
        request.destination = selectedResult

        Task {
            let directions = MKDirections(request: request)
            let response = try? await directions.calculate()
            route = response?.routes.first
        }
    }

    private func fetchPublisherCoordinates(book: Book?) {
        guard let publisherAddress = book?.publisherAddress else { return }

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(publisherAddress) { placemarks, error in
            if let placemark = placemarks?.first, let location = placemark.location {
                self.publisherCoordinate = location.coordinate
            } else {
                print("Error geocoding publisher address: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

#Preview {
    ContentView()
}
