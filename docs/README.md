# MotoBill Documentation Index

This directory contains comprehensive documentation for various features and systems in the MotoBill application.

---

## 📚 Active Documentation

### 🔥 Current Focus: Taxable/Non-Taxable Stock Management

A critical feature for managing separate inventory pools based on tax status of purchases and sales.

**Documents:**
1. **[TAXABLE_STOCK_QUICK_REFERENCE.md](./TAXABLE_STOCK_QUICK_REFERENCE.md)** ⭐ START HERE
   - One-page summary
   - Quick rules and key concepts
   - Perfect for GitHub Copilot context

2. **[TAXABLE_NON_TAXABLE_STOCK_MANAGEMENT.md](./TAXABLE_NON_TAXABLE_STOCK_MANAGEMENT.md)** 📖 DEEP DIVE
   - Complete technical documentation
   - Business rules and database schema
   - Test scenarios and edge cases
   - Implementation status

3. **[TAXABLE_STOCK_IMPLEMENTATION_TODO.md](./TAXABLE_STOCK_IMPLEMENTATION_TODO.md)** 🔧 ACTION ITEMS
   - Step-by-step implementation guide
   - Exact code changes needed
   - Testing checklist
   - Ready to implement

4. **[TAXABLE_STOCK_VISUAL_GUIDE.md](./TAXABLE_STOCK_VISUAL_GUIDE.md)** 🎨 VISUAL AIDS
   - Diagrams and flow charts
   - Visual representations of stock flow
   - Decision trees
   - SQL query patterns

**Status:** 🚧 In Implementation
**Priority:** 🔴 HIGH
**Estimated Time:** 2-4 hours

---

### 📊 Other Features

#### Excel File Tracking
- **[EXCEL_FILE_TRACKING_IMPLEMENTATION.md](./EXCEL_FILE_TRACKING_IMPLEMENTATION.md)**
  - System for tracking uploaded Excel files
  - Prevents duplicate uploads
  - Audit trail for data imports

---

## 📁 Subdirectories

### `db/`
Database-specific documentation:
- Table schemas
- Migration guides
- Database design decisions

**Files:**
- `bank_table.md` - Bank accounts table documentation
- `excel_uploads_table.md` - Excel upload tracking table

### `refactoring/`
Code refactoring documentation:
- HSN code upload improvements
- Product upload system redesign

**Files:**
- `HSN_UPLOAD_REFACTORING.md`
- `PRODUCT_UPLOAD_REFACTORING.md`

---

## 🎯 How to Use This Documentation

### For Developers
1. Start with **QUICK_REFERENCE** docs for overview
2. Read **full documentation** for deep understanding
3. Use **IMPLEMENTATION_TODO** for step-by-step guidance
4. Refer to **VISUAL_GUIDE** when confused

### For GitHub Copilot
These documents are written to provide context for AI-assisted development:
- Clear structure with headings
- Code examples with context
- Business rules explained
- Test scenarios included

### For Project Planning
- Check implementation status sections
- Review TODO checklists
- Estimate time from priority markers
- Track progress through documentation

---

## 📝 Document Structure Standards

All major feature docs should include:
- **Overview**: What is this feature?
- **Business Rules**: How should it work?
- **Database Schema**: What tables/columns are involved?
- **Implementation Status**: What's done, what's not?
- **Test Scenarios**: How to verify it works?
- **Code References**: Where is the relevant code?

---

## 🔄 Document Lifecycle

### Active Documents
Currently being used for ongoing development
- ✅ Kept up-to-date with code changes
- ✅ Referenced in commit messages
- ✅ Updated when requirements change

### Archived Documents
Historical documentation for completed features
- Move to `archive/` subfolder when feature complete
- Keep for reference but mark as historical

### Draft Documents
Work-in-progress documentation
- Mark with [DRAFT] prefix
- May have incomplete sections
- Updated as feature develops

---

## 🤝 Contributing to Documentation

When adding new documentation:

1. **Use Markdown formatting** for consistency
2. **Add to this index** with brief description
3. **Follow naming conventions**:
   - Feature docs: `FEATURE_NAME_DESCRIPTION.md`
   - Quick refs: `FEATURE_QUICK_REFERENCE.md`
   - Implementation: `FEATURE_IMPLEMENTATION_TODO.md`

4. **Include these sections**:
   - Overview/Problem statement
   - Solution approach
   - Implementation details
   - Testing/Verification
   - Related files

5. **Update related documents** when making changes

---

## 🔍 Finding Documentation

### By Feature
- **Stock Management**: TAXABLE_*.md files
- **Data Import**: EXCEL_*.md files
- **Database**: `db/` folder
- **Refactoring**: `refactoring/` folder

### By Type
- **Quick Reference**: *_QUICK_REFERENCE.md
- **Full Documentation**: Most .md files without suffix
- **Implementation Guides**: *_IMPLEMENTATION*.md or *_TODO.md
- **Visual Guides**: *_VISUAL_GUIDE.md

### By Status
- **In Progress**: Check "Status" section in each doc
- **Completed**: Look for ✅ markers
- **Planned**: Look for TODO sections

---

## 📅 Recent Updates

- **2025-01-15**: Created comprehensive taxable/non-taxable stock documentation suite
  - Added 4 detailed documents covering all aspects
  - Included implementation guide and visual aids
  - Ready for development phase

---

## 🎓 Learning Path

**New to the project?** Read in this order:

1. Main `README.md` (project root) - Project overview
2. `.github/copilot-instructions.md` - Project conventions
3. `TAXABLE_STOCK_QUICK_REFERENCE.md` - Current focus area
4. Database schema docs in `db/` - Data structure
5. Feature-specific docs as needed

---

## 💡 Tips

- **Use Ctrl+F** to search within documents
- **Follow links** between related docs
- **Check "Related Files"** sections for code references
- **Run SQL queries** from test scenarios to verify behavior
- **Update docs** when you make code changes

---

**This documentation is a living resource. Keep it updated, clear, and useful!**
